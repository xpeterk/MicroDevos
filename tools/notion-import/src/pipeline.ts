import {
  DisabledEmbeddingProvider,
  KeywordTaggingProvider,
  SEED_TAG_SLUGS,
  type EmbeddingProvider,
  type TaggingProvider,
} from "./enrichment.js";
import {
  bannerPositionWarning,
  readBannerAlt,
  readBannerUrl,
  readDate,
  readStars,
  readStatus,
  readTitle,
  readUrl,
  stripDevotionPrefix,
} from "./notion.js";
import { decide, parseDevoMarkdown } from "./parse.js";
import type { ParsedDevo } from "./types.js";

/** Postgres unique key used by the importer's upsert. */
export const UPSERT_ON_CONFLICT = "notion_page_id,position";

export type SourceCard = {
  id: string;
  properties: Record<string, unknown>;
  markdown: string;
};

export type SkippedCard = { id: string; title: string; reason: string };

export type ImportedDevo = ParsedDevo & {
  tags: string[];
  embedding: number[] | null;
  /** Card property. Not written by the text upsert. */
  notion_banner_url: string | null;
  notion_banner_alt: string | null;
};

export type ImportPlan = {
  imported: ImportedDevo[];
  skipped: SkippedCard[];
  bannerWarnings: string[];
};

export const V6_GUARDED_DATES = new Set([
  "2026-10-19",
  "2026-10-20",
  "2026-10-21",
  "2026-10-22",
  "2026-10-23",
]);

export function isV6GuardedDate(date?: string | null): boolean {
  if (!date) return false;
  return V6_GUARDED_DATES.has(date) || date >= "2026-10-19";
}

export async function planImport(
  cards: SourceCard[],
  options: {
    tagging?: TaggingProvider;
    embedding?: EmbeddingProvider;
    catalog?: string[];
    allowV6?: boolean;
  } = {},
): Promise<ImportPlan> {
  const tagging = options.tagging ?? new KeywordTaggingProvider();
  const embedding = options.embedding ?? new DisabledEmbeddingProvider();
  const catalog = options.catalog ?? SEED_TAG_SLUGS;
  const allowV6 = options.allowV6 ?? process.env.ALLOW_V6_NOTION_IMPORT === "true";
  const imported: ImportedDevo[] = [];
  const skipped: SkippedCard[] = [];
  const bannerWarnings: string[] = [];

  for (const card of cards) {
    const title = readTitle(card.properties);
    const status = readStatus(card.properties);
    const editionDate = readDate(card.properties);
    if (editionDate && isV6GuardedDate(editionDate) && !allowV6) {
      skipped.push({
        id: card.id,
        title,
        reason: `v6 edition date ${editionDate} guarded; Notion cards are stale, loaded via tools/v6-load`,
      });
      continue;
    }
    const normalized = (status ?? "").toLowerCase();
    if (normalized === "ideas" || normalized === "ai-ideas" || title.trim().toLowerCase() === "prompt") {
      skipped.push({
        id: card.id,
        title,
        reason: normalized === "ideas" || normalized === "ai-ideas" ? `status is ${status}` : "non-devo page",
      });
      continue;
    }

    const decision = decide({ status, title, markdown: card.markdown });
    if (!decision.shouldImport) {
      skipped.push({ id: card.id, title, reason: decision.reason });
      continue;
    }

    const devos = parseDevoMarkdown(card.markdown, {
      title,
      status,
      editionDate: readDate(card.properties),
      stars: readStars(card.properties),
      sourceUrl: readUrl(card.properties),
      notionPageId: card.id,
    });
    if (devos.length === 0) {
      skipped.push({ id: card.id, title, reason: "parser found no devotions" });
      continue;
    }

    const notionBannerUrl = readBannerUrl(card.properties);
    const rawBannerAlt = readBannerAlt(card.properties);
    const notionBannerAlt = stripDevotionPrefix(rawBannerAlt);
    for (const devo of devos) {
      const mismatch = bannerPositionWarning({
        headingPosition: devo.position,
        title: devo.title,
        editionDate,
        alt: rawBannerAlt,
      });
      if (mismatch) bannerWarnings.push(mismatch);
      const text = [devo.title, devo.hook, devo.body_md, devo.takeaway].join("\n");
      imported.push({
        ...devo,
        notion_banner_url: notionBannerUrl,
        notion_banner_alt: notionBannerAlt,
        tags: tagging.suggestTags(text, catalog),
        embedding: await embedding.embed(text),
      });
    }
  }

  return { imported, skipped, bannerWarnings };
}

export function toUpsertRows(imported: ImportedDevo[]) {
  return imported.map((devo) => {
    const row: Record<string, unknown> = {
      title: devo.title,
      hook: devo.hook,
      body_md: devo.body_md,
      takeaway: devo.takeaway,
      verse_text: devo.verse_text,
      verse_ref: devo.verse_ref,
      scriptures: devo.scriptures,
      source_url: devo.source_url,
      edition_date: devo.edition_date,
      edition_url: devo.edition_url,
      position: devo.position,
      stars: devo.stars,
      status: (devo.status ?? "published").toLowerCase(),
      notion_page_id: devo.notion_page_id,
      published_at: new Date().toISOString(),
      teaser: devo.teaser ?? "",
      prayer: devo.prayer ?? "",
      // one_minute_* columns are written by the daily-devo routine; never include them here.
    };
    if (devo.embedding) row.embedding = devo.embedding;
    return row;
  });
}
