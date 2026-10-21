import { encodeContent } from "./content.js";

export type ParsedAppSection = {
  position: number;
  title: string;
  summary: string;
  minutes: number;
  verse_ref: string;
  verse_text: string;
  body: string;
  tags: string[];
};

export type AppSectionSplit = {
  prose: string;
  sections: ParsedAppSection[];
};

const appSectionsHeading = /^##\s+App Sections\s*$/m;

/** Removes a trailing App Sections block. Text without one is unchanged. */
export function splitAppSections(section: string): AppSectionSplit {
  const match = appSectionsHeading.exec(section);
  if (!match || match.index === undefined) {
    return { prose: section, sections: [] };
  }
  const prose = section.slice(0, match.index).trim();
  const rest = section.slice(match.index + match[0].length).trim();
  return { prose, sections: parseAppSectionBlock(rest) };
}

export function parseAppSectionBlock(block: string): ParsedAppSection[] {
  const chunks = block.split(/\n(?=###\s+)/);
  const sections: ParsedAppSection[] = [];
  for (const chunk of chunks) {
    const trimmed = chunk.trim();
    if (!trimmed.startsWith("###")) continue;
    const lines = trimmed.split("\n");
    const title = lines[0].replace(/^###\s+/, "").trim();
    if (!title) continue;
    const fields = parseFields(lines.slice(1));
    sections.push({
      position: sections.length + 1,
      title,
      summary: fields.summary,
      minutes: fields.minutes,
      verse_ref: fields.verseRef,
      verse_text: fields.verseText,
      body: encodeContent(fields.body),
      tags: fields.tags,
    });
  }
  return sections;
}

export const SECTION_UPSERT_ON_CONFLICT = "devo_id,position";
export const SECTION_TAGS_ON_CONFLICT = "section_id,tag_id";

export type SectionUpsertRow = {
  devo_id: string;
  position: number;
  title: string;
  summary: string;
  minutes: number;
  verse_ref: string;
  verse_text: string;
  body: string;
};

/** Rows for `upsert(..., { onConflict: "devo_id,position" })`. */
export function buildSectionUpsertRows(
  devoId: string,
  sections: ParsedAppSection[],
): SectionUpsertRow[] {
  return sections.map((section) => ({
    devo_id: devoId,
    position: section.position,
    title: section.title,
    summary: section.summary,
    minutes: section.minutes,
    verse_ref: section.verse_ref,
    verse_text: section.verse_text,
    body: section.body,
  }));
}

export function buildSectionTagLinks(
  sections: Array<{ id: string; tags: string[] }>,
  tagIds: Map<string, string>,
): Array<{ section_id: string; tag_id: string }> {
  const links: Array<{ section_id: string; tag_id: string }> = [];
  for (const section of sections) {
    for (const slug of section.tags) {
      const tagId = tagIds.get(slug);
      if (tagId) links.push({ section_id: section.id, tag_id: tagId });
    }
  }
  return links;
}

function parseFields(lines: string[]) {
  let summary = "";
  let minutes = 1;
  let verseRef = "";
  let verseText = "";
  let tags: string[] = [];
  const body: string[] = [];
  let started = false;
  for (const raw of lines) {
    const trimmed = raw.trim();
    if (!started) {
      if (!trimmed) continue;
      const summaryMatch = /^Summary:\s*(.*)$/i.exec(trimmed);
      if (summaryMatch) {
        summary = summaryMatch[1].trim();
        continue;
      }
      const verseMatch = /^Verse:\s*(.+?)\s*[—–-]\s*[“"]([^”"]+)[”"]\s*$/i.exec(trimmed);
      if (verseMatch) {
        verseRef = verseMatch[1].trim();
        verseText = verseMatch[2].trim();
        continue;
      }
      const tagsMatch = /^Tags:\s*(.*)$/i.exec(trimmed);
      if (tagsMatch) {
        tags = tagSlugs(tagsMatch[1]);
        continue;
      }
      const minutesMatch = /^Minutes:\s*(\d+)/i.exec(trimmed);
      if (minutesMatch) {
        minutes = Math.max(1, Number(minutesMatch[1]));
        continue;
      }
      started = true;
    }
    body.push(raw);
  }
  return {
    summary,
    minutes,
    verseRef,
    verseText,
    tags,
    body: body.join("\n").trim(),
  };
}

function tagSlugs(raw: string): string[] {
  return raw
    .split(",")
    .map((part) =>
      part
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, ""),
    )
    .filter((slug) => slug.length > 0);
}
