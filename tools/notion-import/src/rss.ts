/**
 * Optional banner step. Notion stays the source for devotion text.
 * This module reads the Substack edition feed and returns image_url / image_alt
 * only. It never builds a hook, body, takeaway, or verse from RSS text.
 */

export const DEFAULT_RSS_URL = "https://microdevotionals.substack.com/feed";

export const BANNER_POSITIONS = [1, 2, 3, 4, 5, 6, 7, 8] as const;

const MONTHS: Record<string, number> = {
  january: 1,
  february: 2,
  march: 3,
  april: 4,
  may: 5,
  june: 6,
  july: 7,
  august: 8,
  september: 9,
  october: 10,
  november: 11,
  december: 12,
  jan: 1,
  feb: 2,
  mar: 3,
  apr: 4,
  jun: 6,
  jul: 7,
  aug: 8,
  sep: 9,
  oct: 10,
  nov: 11,
  dec: 12,
};

const NAMED_ENTITIES: Record<string, string> = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: '"',
  apos: "'",
  nbsp: "\u00a0",
};

export type ParsedBanner = {
  position: number;
  title: string;
  imageUrl: string;
  imageAlt: string;
};

export type ParsedEdition = {
  editionDate: string | null;
  title: string;
  link: string;
  banners: ParsedBanner[];
  warnings: string[];
};

export type DevoSlot = {
  editionDate: string;
  position: number;
  title: string;
  /** From the card's Banner property. Null when the property is missing or empty. */
  notionBannerUrl?: string | null;
  notionBannerAlt?: string | null;
};

export type BannerUpdate = {
  editionDate: string;
  position: number;
  imageUrl: string | null;
  imageAlt: string | null;
  matchedBy: "notion" | "title" | "position" | null;
};

export type BannerPlan = {
  updates: BannerUpdate[];
  warnings: string[];
};

type FeedImage = {
  src: string;
  alt: string;
  width: number | null;
  height: number | null;
};

export function decodeXml(value: string): string {
  return value.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z]+);/g, (entity, body: string) => {
    if (body.startsWith("#")) {
      const code = body[1] === "x" || body[1] === "X"
        ? Number.parseInt(body.slice(2), 16)
        : Number.parseInt(body.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : entity;
    }
    return NAMED_ENTITIES[body] ?? entity;
  });
}

export function normalizeTitle(value: string): string {
  return value
    .normalize("NFKC")
    .replace(/[’‘]/g, "'")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

export function parseRssFeed(xml: string): ParsedEdition[] {
  const editions: ParsedEdition[] = [];
  const itemRe = /<item\b[^>]*>([\s\S]*?)<\/item>/gi;
  let match: RegExpExecArray | null;
  while ((match = itemRe.exec(xml))) {
    editions.push(parseItem(match[1]));
  }
  return editions;
}

export function matchBanners(editions: ParsedEdition[], devos: DevoSlot[] = []): BannerPlan {
  const warnings: string[] = [];
  const updates: BannerUpdate[] = [];
  const editionsByDate = new Map<string, ParsedEdition>();

  for (const edition of editions) {
    warnings.push(...edition.warnings);
    if (!edition.editionDate) continue;
    if (editionsByDate.has(edition.editionDate)) {
      warnings.push(
        `duplicate RSS post for ${edition.editionDate} ("${edition.title}"); kept the first post`,
      );
      continue;
    }
    editionsByDate.set(edition.editionDate, edition);
  }

  if (devos.length === 0) {
    for (const edition of editionsByDate.values()) {
      const byPosition = new Map(edition.banners.map((banner) => [banner.position, banner]));
      for (const position of BANNER_POSITIONS) {
        const banner = byPosition.get(position);
        updates.push(
          banner
            ? {
                editionDate: edition.editionDate!,
                position,
                imageUrl: banner.imageUrl,
                imageAlt: banner.imageAlt,
                matchedBy: "position",
              }
            : {
                editionDate: edition.editionDate!,
                position,
                imageUrl: null,
                imageAlt: null,
                matchedBy: null,
              },
        );
      }
    }
    return { updates, warnings };
  }

  const grouped = new Map<string, DevoSlot[]>();
  for (const devo of devos) {
    const rows = grouped.get(devo.editionDate) ?? [];
    rows.push(devo);
    grouped.set(devo.editionDate, rows);
  }

  for (const [editionDate, rows] of grouped) {
    const edition = editionsByDate.get(editionDate);
    if (!edition) {
      for (const devo of rows) {
        if (!present(devo.notionBannerUrl) && !present(devo.notionBannerAlt)) continue;
        updates.push(resolveDevoBanner(editionDate, undefined, devo, new Set(), warnings));
      }
      continue;
    }
    const remaining = new Set(edition.banners);
    for (const devo of rows) {
      updates.push(resolveDevoBanner(editionDate, edition, devo, remaining, warnings));
    }
  }

  return { updates, warnings };
}

function resolveDevoBanner(
  editionDate: string,
  edition: ParsedEdition | undefined,
  devo: DevoSlot,
  remaining: Set<ParsedBanner>,
  warnings: string[],
): BannerUpdate {
  const notionUrl = present(devo.notionBannerUrl);
  const notionAlt = present(devo.notionBannerAlt);
  const rss = edition ? rssBannerFor(edition, devo, remaining, warnings, notionUrl == null) : undefined;
  const imageUrl = notionUrl ?? rss?.banner.imageUrl ?? null;
  const imageAlt = notionAlt ?? rss?.banner.imageAlt ?? null;
  if (!imageUrl) {
    warnings.push(
      `no banner match for ${editionDate} position ${devo.position} ("${devo.title}"); image_url left null`,
    );
  }
  return {
    editionDate,
    position: devo.position,
    imageUrl,
    imageAlt,
    matchedBy: notionUrl ? "notion" : rss?.matchedBy ?? null,
  };
}

function rssBannerFor(
  edition: ParsedEdition,
  devo: DevoSlot,
  remaining: Set<ParsedBanner>,
  warnings: string[],
  consume: boolean,
): { banner: ParsedBanner; matchedBy: "title" | "position" } | undefined {
  const titleKey = normalizeTitle(devo.title);
  if (titleKey) {
    const hits = edition.banners.filter(
      (banner) => remaining.has(banner) && normalizeTitle(banner.title) === titleKey,
    );
    if (hits.length > 1) {
      warnings.push(
        `title "${devo.title}" matched ${hits.length} banners on ${edition.editionDate}; using position`,
      );
    } else if (hits.length === 1) {
      if (consume) remaining.delete(hits[0]);
      return { banner: hits[0], matchedBy: "title" };
    }
  }
  const banner = edition.banners.find(
    (candidate) => remaining.has(candidate) && candidate.position === devo.position,
  );
  if (!banner) return undefined;
  if (consume) remaining.delete(banner);
  return { banner, matchedBy: "position" };
}

function present(value: string | null | undefined): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed || null;
}

/** Columns the RSS step is allowed to write. Notion text is not in this object. */
export function bannerWritePayload(update: BannerUpdate): {
  image_url: string | null;
  image_alt: string | null;
} {
  return {
    image_url: update.imageUrl,
    image_alt: update.imageAlt,
  };
}

export function formatBannerReport(source: string, editions: ParsedEdition[]): string {
  const lines = [`RSS dry run: ${source}`];
  let matched = 0;
  let unmatched = 0;
  let dated = 0;
  for (const edition of editions) {
    if (!edition.editionDate) {
      lines.push(`undated  matched 0/8  ${edition.title}`);
      unmatched += BANNER_POSITIONS.length;
      continue;
    }
    dated += 1;
    const positions = new Set(edition.banners.map((banner) => banner.position));
    const missing = BANNER_POSITIONS.filter((position) => !positions.has(position)).length;
    lines.push(`${edition.editionDate}  matched ${edition.banners.length}/8  ${edition.title}`);
    matched += edition.banners.length;
    unmatched += missing;
  }
  lines.push(`${dated} editions, ${matched} banners matched, ${unmatched} left null`);
  return lines.join("\n");
}

export function logBannerWarnings(
  warnings: string[],
  warn: (message: string) => void = console.warn,
) {
  for (const warning of warnings) warn(`warning: ${warning}`);
}

export async function loadFeedXml(options: {
  fixturePath?: string;
  url?: string;
  readFile?: (file: string) => Promise<string>;
  fetchText?: (url: string) => Promise<string>;
}): Promise<{ xml: string; source: string }> {
  if (options.fixturePath) {
    const readFile = options.readFile;
    if (!readFile) throw new Error("readFile is required when loading an RSS fixture");
    return { xml: await readFile(options.fixturePath), source: options.fixturePath };
  }
  const url = options.url || process.env.RSS_FEED_URL || DEFAULT_RSS_URL;
  const fetchText = options.fetchText ?? defaultFetchText;
  return { xml: await fetchText(url), source: url };
}

async function defaultFetchText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`RSS feed ${url} returned ${response.status}`);
  }
  return response.text();
}

function parseItem(block: string): ParsedEdition {
  const title = textContent(block, "title");
  const link = textContent(block, "link");
  const pubDate = textContent(block, "pubDate");
  const dated = editionDate(title, pubDate);
  const warnings = dated.warning ? [dated.warning] : [];
  const content = textContent(block, "content:encoded");
  const banners = bannersFromHtml(content, warnings);
  if (!dated.date) {
    warnings.push(`RSS item "${title || link || "untitled"}" has no edition date`);
  }
  return {
    editionDate: dated.date,
    title,
    link,
    banners,
    warnings,
  };
}

function bannersFromHtml(html: string, warnings: string[]): ParsedBanner[] {
  const images = [...html.matchAll(/<img\b[^>]*>/gi)].map((match) => readImage(match[0]));
  const banners: ParsedBanner[] = [];
  const used = new Set<number>();
  const unlabeled: FeedImage[] = [];

  for (const image of images) {
    if (isCover(image)) continue;
    const labeled = /^Devotion\s+(\d+)\s*:\s*(.*)$/i.exec(image.alt.trim());
    if (!isSubstackCdn(image.src)) {
      const label = labeled ? titleFromAlt(labeled[2]) : image.alt.trim() || image.src;
      warnings.push(`skipped a non-CDN image for "${label}"`);
      continue;
    }
    if (!labeled) {
      unlabeled.push(image);
      continue;
    }
    const position = Number(labeled[1]);
    const title = titleFromAlt(labeled[2]);
    if (position < 1 || position > 8) {
      warnings.push(`ignored banner position ${position} ("${title}")`);
      continue;
    }
    if (used.has(position)) {
      warnings.push(`duplicate banner for position ${position} ("${title}")`);
      continue;
    }
    used.add(position);
    banners.push({
      position,
      title,
      imageUrl: image.src,
      imageAlt: image.alt.trim(),
    });
  }

  for (const image of unlabeled) {
    const position = BANNER_POSITIONS.find((slot) => !used.has(slot));
    if (!position) {
      warnings.push(`extra image had no free position: ${image.src}`);
      continue;
    }
    used.add(position);
    banners.push({
      position,
      title: "",
      imageUrl: image.src,
      imageAlt: image.alt.trim(),
    });
  }

  for (const position of BANNER_POSITIONS) {
    if (!used.has(position)) warnings.push(`no banner for position ${position}`);
  }

  banners.sort((left, right) => left.position - right.position);
  return banners;
}

function readImage(tag: string): FeedImage {
  const attrs = tagAttributes(tag);
  return {
    src: attrs.src ?? "",
    alt: attrs.alt ?? "",
    width: numberAttr(attrs.width),
    height: numberAttr(attrs.height),
  };
}

function tagAttributes(tag: string): Record<string, string> {
  const attrs: Record<string, string> = {};
  const re = /([:\w-]+)\s*=\s*"([^"]*)"/g;
  let match: RegExpExecArray | null;
  while ((match = re.exec(tag))) {
    attrs[match[1].toLowerCase()] = decodeXml(match[2]);
  }
  return attrs;
}

function isCover(image: FeedImage): boolean {
  if (/^Devotion\s+\d+\s*:/i.test(image.alt.trim())) return false;
  if (!image.alt.trim()) return true;
  return image.width === 1200 && image.height === 630;
}

function isSubstackCdn(src: string): boolean {
  return src.startsWith("https://substackcdn.com/") || src.includes("substack-post-media.s3.amazonaws.com");
}

function titleFromAlt(rest: string): string {
  const period = rest.indexOf(".");
  return (period >= 0 ? rest.slice(0, period) : rest).trim();
}

function numberAttr(value: string | undefined): number | null {
  if (!value) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function textContent(block: string, tag: string): string {
  const re = new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)</${tag}>`, "i");
  const match = re.exec(block);
  return match ? unwrap(match[1]).trim() : "";
}

function unwrap(value: string): string {
  const trimmed = value.trim();
  const cdata = /^<!\[CDATA\[([\s\S]*?)\]\]>$/.exec(trimmed);
  return cdata ? cdata[1].trim() : trimmed;
}

function editionDate(title: string, pubDate: string): { date: string | null; warning?: string } {
  const fromTitle = dateFromLongForm(title);
  const fromPub = dateFromRfc822(pubDate);
  if (fromTitle && fromPub && fromTitle !== fromPub) {
    return {
      date: fromTitle,
      warning: `title date ${fromTitle} differs from pubDate ${fromPub}; using the title`,
    };
  }
  if (fromTitle) return { date: fromTitle };
  if (fromPub) return { date: fromPub, warning: `edition date taken from pubDate ${fromPub}` };
  return { date: null };
}

function dateFromLongForm(title: string): string | null {
  const match = /([A-Za-z]+)\s+(\d{1,2}),\s+(\d{4})/.exec(title);
  if (!match) return null;
  const month = MONTHS[match[1].toLowerCase()];
  if (!month) return null;
  return isoDate(Number(match[3]), month, Number(match[2]));
}

function dateFromRfc822(pubDate: string): string | null {
  const match = /,\s*(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})/.exec(pubDate);
  if (!match) return null;
  const month = MONTHS[match[2].toLowerCase()];
  if (!month) return null;
  return isoDate(Number(match[3]), month, Number(match[1]));
}

function isoDate(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
}
