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

export type DevoSectionPrunePlan =
  | { deleteIssued: false }
  | { deleteIssued: true; keep: number[]; notIn: string };

/**
 * `deleteIssued: false` means do not delete.
 * A card with no Notion sections must not wipe sections loaded from v6 content files.
 * When Notion supplies sections, `notIn` is the PostgREST list of positions to retain.
 */
export function planDevoSectionPrune(
  sections: Array<{ position: number }> | null | undefined,
): DevoSectionPrunePlan {
  const keep = (sections ?? []).map((section) => section.position);
  if (keep.length === 0) return { deleteIssued: false };
  return { deleteIssued: true, keep, notIn: `(${keep.join(",")})` };
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

const inlineHeading = /^###\s+\S/m;

/** Turns v6 ### headings into sections. Older ### body headings stay prose. */
export function splitInlineSections(prose: string): AppSectionSplit {
  const heading = inlineHeading.exec(prose);
  if (!heading || heading.index === undefined) {
    return { prose, sections: [] };
  }
  const intro = prose.slice(0, heading.index).trim();
  if (!introHasV6Lead(intro)) return { prose, sections: [] };
  const chunks = prose.slice(heading.index).split(/\n(?=###\s+)/);
  const sections: ParsedAppSection[] = [];
  chunks.forEach((chunk, index) => {
    const trimmed = chunk.trim();
    if (!trimmed.startsWith("###")) return;
    const lines = trimmed.split("\n");
    const title = lines[0].replace(/^###\s+/, "").trim();
    if (!title) return;
    const bodyLines =
      index === chunks.length - 1 ? withoutTrailer(lines.slice(1)) : lines.slice(1);
    const body = bodyLines.join("\n").trim();
    const verse = verseFromBody(body);
    sections.push({
      position: sections.length + 1,
      title,
      summary: "",
      minutes: 1,
      verse_ref: verse.reference,
      verse_text: verse.text,
      body: encodeContent(body),
      tags: [],
    });
  });
  if (sections.length === 0) return { prose, sections: [] };
  return { prose: intro, sections };
}

function introHasV6Lead(intro: string): boolean {
  const bold = /\*\*(.+?)\*\*/;
  const italic = /(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/;
  for (const raw of intro.split("\n")) {
    const trimmed = raw.trim();
    if (!trimmed) continue;
    if (bold.test(trimmed) && italic.test(trimmed)) return true;
  }
  return false;
}

function withoutTrailer(lines: string[]): string[] {
  const kept: string[] = [];
  for (const line of lines) {
    if (isTrailer(line)) break;
    kept.push(line);
  }
  return kept;
}

function isTrailer(line: string): boolean {
  const trimmed = line.trim();
  if (!trimmed) return false;
  const plain = trimmed.replaceAll("**", "").trim();
  if (plain.startsWith("🙏")) return true;
  if (/^Today\b/i.test(plain)) return true;
  if (/^Share card\s*:/i.test(plain)) return true;
  if (/^Source\s*:/i.test(plain)) return true;
  if (/^Edition\s*:/i.test(plain)) return true;
  if (trimmed.startsWith(":::")) return true;
  if (/^\*\*[^*].+\*\*$/.test(trimmed)) return true;
  return false;
}

function verseFromBody(body: string): { reference: string; text: string } {
  const quote = /^>\s*(.+)$/m.exec(body)?.[1]?.trim() ?? "";
  const match =
    /^(.*?)(?:\s+[—–-]\s*|\s+)((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)(?:\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB))?\s*$/.exec(
      quote,
    );
  if (!match) return { reference: "", text: "" };
  return { reference: match[2].trim(), text: match[1].trim() };
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
