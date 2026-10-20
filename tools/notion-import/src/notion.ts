import type { NotionBlock } from "./types.js";

const NOTION_VERSIONS = ["2025-09-03", "2022-06-28"] as const;

export type NotionPage = {
  id: string;
  properties: Record<string, unknown>;
};

type QueryResponse = {
  results: NotionPage[];
  has_more: boolean;
  next_cursor: string | null;
};

type BlockList = {
  results: NotionBlock[];
  has_more: boolean;
  next_cursor: string | null;
};

export class NotionClient {
  constructor(
    private readonly token: string,
    private readonly dataSourceId: string,
  ) {}

  async queryPages(): Promise<NotionPage[]> {
    const pages: NotionPage[] = [];
    let cursor: string | null = null;
    for (;;) {
      const body: Record<string, unknown> = { page_size: 100 };
      if (cursor) body.start_cursor = cursor;
      const response = await this.post<QueryResponse>(this.queryPaths(), body);
      pages.push(...response.results);
      if (!response.has_more || !response.next_cursor) return pages;
      cursor = response.next_cursor;
    }
  }

  async pageMarkdown(pageId: string): Promise<string> {
    const { blocksToMarkdown } = await import("./blocks.js");
    const blocks = await this.blockChildren(pageId);
    return blocksToMarkdown(blocks);
  }

  private queryPaths(): string[] {
    return [
      `/data_sources/${this.dataSourceId}/query`,
      `/databases/${this.dataSourceId}/query`,
    ];
  }

  private async blockChildren(blockId: string): Promise<NotionBlock[]> {
    const blocks: NotionBlock[] = [];
    let cursor: string | null = null;
    for (;;) {
      const query = cursor
        ? `&start_cursor=${encodeURIComponent(cursor)}`
        : "";
      const endpoint: string = `/blocks/${blockId}/children?page_size=100${query}`;
      const response: BlockList = await this.get<BlockList>(endpoint);
      for (const block of response.results) {
        if (block.has_children && block.id) {
          block.children = await this.blockChildren(block.id);
        }
        blocks.push(block);
      }
      if (!response.has_more || !response.next_cursor) return blocks;
      cursor = response.next_cursor;
    }
  }

  private async get<T>(path: string): Promise<T> {
    return this.request<T>(path, undefined);
  }

  private async post<T>(paths: string[], body: unknown): Promise<T> {
    let lastError: Error | null = null;
    for (const path of paths) {
      try {
        return await this.request<T>(path, body);
      } catch (error) {
        lastError = error as Error;
      }
    }
    throw lastError ?? new Error("Notion query failed");
  }

  private async request<T>(path: string, body: unknown): Promise<T> {
    let lastMessage = "Notion request failed";
    for (const version of NOTION_VERSIONS) {
      const response = await fetch(`https://api.notion.com/v1${path}`, {
        method: body === undefined ? "GET" : "POST",
        headers: {
          Authorization: `Bearer ${this.token}`,
          "Notion-Version": version,
          "Content-Type": "application/json",
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });
      if (response.status === 429) {
        const wait = Number(response.headers.get("retry-after") ?? "1");
        await new Promise((resolve) => setTimeout(resolve, wait * 1000));
        return this.request(path, body);
      }
      if (response.ok) return (await response.json()) as T;
      lastMessage = `${response.status} ${await response.text()}`;
      if (response.status !== 400 && response.status !== 404) break;
    }
    throw new Error(lastMessage);
  }
}

export function readTitle(properties: Record<string, unknown>): string {
  return plainProperty(properties.Idea ?? properties.Name ?? properties.title);
}

export function readStatus(properties: Record<string, unknown>): string | null {
  return selectName(properties.Status);
}

export function readDate(properties: Record<string, unknown>): string | null {
  const date = properties.Date as { date?: { start?: string } } | undefined;
  return date?.date?.start?.slice(0, 10) ?? null;
}

export function readUrl(properties: Record<string, unknown>): string | null {
  const url = properties.URL as { url?: string | null } | undefined;
  return url?.url ?? null;
}

/**
 * Banner is optional. The property is absent until it is added to the database,
 * and it may be either a URL property or a Files property.
 * Missing, null, and blank all mean "no Notion banner".
 */
export function readBannerUrl(properties: Record<string, unknown> | null | undefined): string | null {
  if (!properties) return null;
  const banner = properties.Banner ?? properties.banner;
  if (!banner || typeof banner !== "object") return null;
  const record = banner as Record<string, unknown>;
  const direct = presentText(record.url);
  if (direct) return direct;
  if (!Array.isArray(record.files)) return null;
  for (const file of record.files) {
    if (!file || typeof file !== "object") continue;
    const item = file as Record<string, unknown>;
    const external = item.external as { url?: unknown } | undefined;
    const hosted = item.file as { url?: unknown } | undefined;
    const url = presentText(external?.url) ?? presentText(hosted?.url) ?? presentText(item.url);
    if (url) return url;
  }
  return null;
}

const devotionPrefix = /^Devotion\s+(\d+)\s*:\s*/i;

/** The "Devotion N:" prefix on Banner Alt, when the text has one. */
export function bannerAltPosition(alt: string | null | undefined): number | null {
  const text = presentText(alt);
  if (!text) return null;
  const match = devotionPrefix.exec(text);
  if (!match) return null;
  const position = Number(match[1]);
  return position >= 1 && position <= 8 ? position : null;
}

/** Drop "Devotion N:" so the stored alt starts with the devotion title. */
export function stripDevotionPrefix(alt: string | null | undefined): string | null {
  const text = presentText(alt);
  if (!text) return null;
  const stripped = text.replace(devotionPrefix, "").trim();
  return stripped || null;
}

/**
 * Position comes from the "## N · …" heading. Banner Alt's prefix is a check.
 * A mismatch keeps the heading and returns a warning.
 */
export function bannerPositionWarning(input: {
  headingPosition: number;
  title: string;
  editionDate?: string | null;
  alt: string | null | undefined;
}): string | null {
  const fromAlt = bannerAltPosition(input.alt);
  if (fromAlt == null || fromAlt === input.headingPosition) return null;
  const when = input.editionDate ? `, ${input.editionDate}` : "";
  return `banner alt says Devotion ${fromAlt} but the heading is ${input.headingPosition} ("${input.title}"${when}); using the heading`;
}

/** Banner Alt is optional rich text. A missing property returns null. */
export function readBannerAlt(properties: Record<string, unknown> | null | undefined): string | null {
  if (!properties) return null;
  const banner = properties["Banner Alt"] ?? properties.banner_alt;
  if (!banner || typeof banner !== "object") return null;
  const rich = (banner as { rich_text?: unknown }).rich_text;
  if (!Array.isArray(rich)) return null;
  const text = rich
    .map((part) => {
      if (!part || typeof part !== "object") return "";
      return presentText((part as { plain_text?: unknown }).plain_text) ?? "";
    })
    .join("")
    .trim();
  return text || null;
}

export function readStars(properties: Record<string, unknown>): number | null {
  const name = selectName(properties.Stars);
  if (!name) return null;
  const count = name.match(/★/g)?.length ?? 0;
  return count || null;
}

function presentText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

function selectName(value: unknown): string | null {
  if (!value || typeof value !== "object") return null;
  const name = (value as { select?: { name?: string } | null }).select?.name;
  return name ?? null;
}

function plainProperty(value: unknown): string {
  if (!value || typeof value !== "object") return "";
  const title = (value as { title?: Array<{ plain_text?: string }> }).title;
  if (!title) return "";
  return title.map((part) => part.plain_text ?? "").join("");
}
