import type { ImportedDevo } from "./pipeline.js";

export type SavedDevo = {
  id: string;
  notion_page_id: string | null;
  position: number;
};

export type TagRow = { id: string; slug: string };

export type TagLink = { devo_id: string; tag_id: string };

/** Same conflict target the Supabase client uses for devo_tags. */
export const DEVO_TAGS_ON_CONFLICT = "devo_id,tag_id";

/** Slugs the catalog does not know. Callers skip these and log them. */
export function unknownTagSlugs(
  slugs: Iterable<string>,
  tagIds: Map<string, string>,
): string[] {
  const missing = new Set<string>();
  for (const slug of slugs) {
    if (!tagIds.has(slug)) missing.add(slug);
  }
  return [...missing].sort();
}

export function logUnknownTags(slugs: Iterable<string>): void {
  for (const slug of slugs) {
    console.warn(`Skipping unknown tag "${slug}"`);
  }
}

export function savedKey(notionPageId: string | null, position: number): string {
  return `${notionPageId}:${position}`;
}

/** Pair each imported devotion's tag slugs with the rows just upserted. */
export function buildDevoTagLinks(
  imported: Array<Pick<ImportedDevo, "notion_page_id" | "position" | "tags">>,
  saved: Map<string, string>,
  tagIds: Map<string, string>,
): TagLink[] {
  const links: TagLink[] = [];
  for (const devo of imported) {
    const devoId = saved.get(savedKey(devo.notion_page_id, devo.position));
    if (!devoId) continue;
    for (const slug of devo.tags) {
      const tagId = tagIds.get(slug);
      if (tagId) links.push({ devo_id: devoId, tag_id: tagId });
    }
  }
  return links;
}

/**
 * SQL for `.from("devo_tags").upsert(links, { onConflict: "devo_id,tag_id" })`.
 * Running it twice keeps one row per pair.
 */
export function devoTagUpsertStatement(links: TagLink[]): { text: string; values: string[] } {
  if (links.length === 0) {
    return { text: "select 0", values: [] };
  }
  const values: string[] = [];
  const tuples = links.map((link, index) => {
    const devo = index * 2 + 1;
    const tag = index * 2 + 2;
    values.push(link.devo_id, link.tag_id);
    return `($${devo}::uuid, $${tag}::uuid)`;
  });
  return {
    text: `insert into public.devo_tags (devo_id, tag_id)
values ${tuples.join(", ")}
on conflict (devo_id, tag_id) do update
set devo_id = excluded.devo_id,
    tag_id = excluded.tag_id`,
    values,
  };
}
