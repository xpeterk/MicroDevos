import { encodeContent } from "./content.js";
import type { CardMeta, ImportDecision, ParsedDevo, ScriptureQuote } from "./types.js";

const numberedHeading = /^##\s+(\d+)\s*[·•|\-–—]\s+(.+?)\s*$/gm;
const substackLink = /\[([^\]]*)\]\((https?:\/\/[^)\s]*substack\.com[^)\s]*)\)/g;
const anyLink = /\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)/;
const versionSuffix = /\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB)\s*$/;

export function starsFromLabel(label: string | null | undefined): number | null {
  if (!label) return null;
  const count = label.match(/★/g)?.length ?? 0;
  if (count === 0) return null;
  return Math.min(count, 3);
}

export function editionUrlFrom(markdown: string): string | null {
  for (const line of markdown.split("\n")) {
    const lower = line.toLowerCase();
    const mentionsEdition = lower.includes("edition");
    for (const match of line.matchAll(substackLink)) {
      const text = (match[1] ?? "").toLowerCase();
      if (mentionsEdition || text.includes("micro devos")) {
        return withoutFragment(match[2]);
      }
    }
  }
  return null;
}

export function decide(input: {
  status?: string | null;
  title: string;
  markdown: string;
}): ImportDecision {
  const status = (input.status ?? "").trim().toLowerCase();
  if (status === "ideas" || status === "ai-ideas") {
    return { shouldImport: false, reason: `status is ${input.status}` };
  }
  const title = input.title.trim().toLowerCase();
  if (title === "prompt" || title.startsWith("prompt ") || title.startsWith("prompt:")) {
    return { shouldImport: false, reason: "non-devo page" };
  }
  if (!editionUrlFrom(input.markdown)) {
    return { shouldImport: false, reason: "no edition link" };
  }
  if (!numberedHeading.test(input.markdown)) {
    numberedHeading.lastIndex = 0;
    return { shouldImport: false, reason: "no numbered devotion heading" };
  }
  numberedHeading.lastIndex = 0;
  return { shouldImport: true };
}

export function parseDevoMarkdown(markdown: string, meta: CardMeta = {}): ParsedDevo[] {
  const text = markdown.replaceAll("\r\n", "\n").trim();
  const editionUrl = editionUrlFrom(text) ?? firstSubstack(text);
  const sourceUrl = sourceUrlFrom(text) ?? meta.sourceUrl ?? null;
  numberedHeading.lastIndex = 0;
  const headings = [...text.matchAll(numberedHeading)];
  if (headings.length === 0) return [];

  const preamble = text.slice(0, headings[0].index ?? 0);
  const hook = hookFrom(preamble);
  const glance = glanceScriptures(preamble);
  const devos: ParsedDevo[] = [];

  headings.forEach((heading, index) => {
    const start = (heading.index ?? 0) + heading[0].length;
    const end = index + 1 < headings.length ? headings[index + 1].index ?? text.length : text.length;
    const section = parseSection(text.slice(start, end).trim());
    devos.push({
      title: stripLeadingSymbols(heading[2].trim()),
      hook,
      body_md: encodeContent(section.body),
      takeaway: section.takeaway,
      verse_text: section.verseText,
      verse_ref: section.verseRef,
      scriptures: unique([...glance, ...section.scriptures]),
      source_url: sourceUrl,
      edition_date: meta.editionDate ?? null,
      edition_url: editionUrl,
      position: Number(heading[1]),
      stars: meta.stars ?? null,
      status: meta.status ?? null,
      notion_page_id: meta.notionPageId ?? null,
    });
  });
  return devos;
}

function parseSection(section: string) {
  const callout = /:::callout\s*\n([\s\S]*?)\n:::/.exec(section);
  const verse = callout ? verseFromCallout(callout[1]) : { text: "", reference: "" };
  let body = section;
  if (callout) body = body.slice(0, callout.index) + body.slice(callout.index + callout[0].length);

  const kept: string[] = [];
  const quoteLines: string[] = [];
  const quoteBuffer: string[] = [];
  let sticky: string | undefined;
  let todayStep: string | undefined;
  let lastBold: string | undefined;

  const flush = () => {
    if (quoteBuffer.length === 0) return;
    quoteLines.push(quoteBuffer.join(" ").trim());
    quoteBuffer.length = 0;
  };

  for (const raw of body.split("\n")) {
    const trimmed = raw.trim();
    if (trimmed.startsWith(">")) {
      quoteBuffer.push(trimmed.replace(/^>\s?/, ""));
      continue;
    }
    flush();
    if (!trimmed) {
      kept.push("");
      continue;
    }
    if (isSourceOrEdition(trimmed) || trimmed === "---") continue;
    const stickyOpen = /^\*\*Sticky lesson:\*\*\s*(.+)$/i.exec(trimmed);
    const stickyWrapped = /^\*\*Sticky lesson:\s*(.+?)\*\*$/i.exec(trimmed);
    if (stickyOpen || stickyWrapped) {
      sticky = (stickyOpen?.[1] ?? stickyWrapped?.[1] ?? "").trim();
      continue;
    }
    if (!todayStep && /^Today\b/.test(trimmed)) {
      todayStep = plain(trimmed);
      continue;
    }
    if (/^\*\*[^*].+\*\*$/.test(trimmed)) lastBold = plain(trimmed);
    kept.push(trimmed);
  }
  flush();

  let takeaway = sticky ?? todayStep ?? "";
  if (!takeaway && lastBold) {
    takeaway = lastBold;
    const index = findLastIndex(
      kept,
      (line) => line === `**${lastBold}**` || plain(line) === lastBold,
    );
    if (index >= 0) kept.splice(index, 1);
  }

  const scriptures = quoteLines
    .map(scriptureFromQuote)
    .filter((quote): quote is ScriptureQuote => quote !== null);
  if (
    verse.reference &&
    verse.text &&
    scriptures.every((quote) => quote.reference !== verse.reference)
  ) {
    scriptures.push({ reference: verse.reference, text: verse.text });
  }

  return {
    body: kept.join("\n").replace(/\n{3,}/g, "\n\n").trim(),
    takeaway,
    verseText: verse.text,
    verseRef: verse.reference,
    scriptures,
  };
}

function verseFromCallout(callout: string) {
  const lines = callout.split("\n").map((line) => line.trim()).filter(Boolean);
  let reference = "";
  const textLines: string[] = [];
  for (const line of lines) {
    const value = stripLeadingSymbols(plain(line));
    if (value.toUpperCase().startsWith("VERSE")) {
      const ref = verseRef(value);
      if (ref) reference = cleanRef(ref);
      continue;
    }
    const trailing = trailingRef(value);
    if (trailing) {
      if (!reference) reference = trailing.reference;
      if (trailing.text) textLines.push(trailing.text);
    } else {
      textLines.push(unwrapQuotes(value));
    }
  }
  return { text: textLines.join(" ").trim(), reference };
}

function scriptureFromQuote(quote: string): ScriptureQuote | null {
  const trailing = trailingRef(unwrapQuotes(plain(quote)));
  if (!trailing) return null;
  return { reference: trailing.reference, text: trailing.text };
}

function trailingRef(line: string): { text: string; reference: string } | null {
  const match =
    /^(.*?)(?:\s+[—–-]\s*|\s+)((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)(?:\s+(?:ESV|NIV|KJV|NLT|NKJV|CSB|NASB))?\s*$/.exec(
      line.trim(),
    );
  if (!match) return null;
  const text = unwrapQuotes(match[1].trim());
  if (!text) return null;
  return { text, reference: cleanRef(match[2]) };
}

function verseRef(line: string): string | null {
  return /((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)/.exec(line)?.[1] ?? null;
}

function hookFrom(preamble: string): string {
  for (const line of preamble.split("\n")) {
    const bold = /\*\*(.+?)\*\*/.exec(line);
    if (!bold) continue;
    if (bold[1].trim().toLowerCase().startsWith("at a glance")) continue;
    return stripLeadingSymbols(bold[1].trim());
  }
  return "";
}

function glanceScriptures(preamble: string): ScriptureQuote[] {
  const quotes: ScriptureQuote[] = [];
  for (const raw of preamble.split("\n")) {
    const line = raw.trim();
    if (!line || line.startsWith("#") || line.startsWith("**")) continue;
    const match =
      /^((?:[1-3]\s)?(?:[A-Z][A-Za-z]+\.?\s+){1,3}\d+:\d+(?:-\d+)?)\s*:\s+(.+)$/.exec(line);
    if (!match) continue;
    quotes.push({ reference: cleanRef(match[1]), text: match[2].trim() });
  }
  return quotes;
}

function isSourceOrEdition(line: string): boolean {
  const lower = line.toLowerCase();
  return (
    lower.startsWith("**source:") ||
    lower.startsWith("source:") ||
    lower.startsWith("edition:") ||
    lower.startsWith("**edition:")
  );
}

function sourceUrlFrom(markdown: string): string | null {
  for (const line of markdown.split("\n")) {
    if (!line.toLowerCase().includes("source")) continue;
    const match = anyLink.exec(line);
    anyLink.lastIndex = 0;
    if (match) return match[2];
  }
  return null;
}

function firstSubstack(markdown: string): string | null {
  substackLink.lastIndex = 0;
  const match = substackLink.exec(markdown);
  substackLink.lastIndex = 0;
  return match ? withoutFragment(match[2]) : null;
}

function withoutFragment(url: string): string {
  const hash = url.indexOf("#");
  return hash < 0 ? url : url.slice(0, hash);
}

function cleanRef(reference: string): string {
  return reference.replace(versionSuffix, "").replace(/\s+/g, " ").trim();
}

function plain(line: string): string {
  return line
    .replace(/\*\*(.+?)\*\*/g, "$1")
    .replace(/(?<!\*)\*(.+?)\*(?!\*)/g, "$1")
    .trim();
}

function unwrapQuotes(value: string): string {
  let text = value.trim();
  const wrappers = new Set(['"', "'", "“", "”", "‘", "’"]);
  while (text && wrappers.has(text[0])) text = text.slice(1).trimStart();
  while (text && wrappers.has(text[text.length - 1])) text = text.slice(0, -1).trimEnd();
  return text.trim();
}

function stripLeadingSymbols(input: string): string {
  return input.replace(/^[^\p{L}\p{N}]+/u, "").trim();
}

function findLastIndex<T>(items: T[], predicate: (item: T) => boolean): number {
  for (let index = items.length - 1; index >= 0; index--) {
    if (predicate(items[index])) return index;
  }
  return -1;
}

function unique(quotes: ScriptureQuote[]): ScriptureQuote[] {
  const seen = new Set<string>();
  return quotes.filter((quote) => {
    const key = `${quote.reference}|${quote.text}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
