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

export function readStars(properties: Record<string, unknown>): number | null {
  const name = selectName(properties.Stars);
  if (!name) return null;
  const count = name.match(/★/g)?.length ?? 0;
  return count || null;
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
