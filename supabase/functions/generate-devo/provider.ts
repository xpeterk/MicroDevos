// Generation is behind this interface. The default is a fake provider.
// A later real provider implements GenerationProvider and is selected with
// GENERATION_PROVIDER. Do not add a model API key here.

export type Scripture = { reference: string; text: string };

export type GenerateInput = {
  verseMode: boolean;
  topic: string;
  verseRefs: string[];
  styleKey: string;
  ageRange: string | null;
  lifeSituations: string[];
  generationNotes: string;
  bibleVersion: string | null;
};

export type GenerationDraft = {
  title: string;
  hook: string;
  sections: string[];
  takeaway: string;
  verse_text: string;
  verse_ref: string;
  scriptures: Scripture[];
  help_note?: string | null;
  cost_usd: number;
  tokens_in: number;
  tokens_out: number;
  embedding: number[] | null;
};

export interface GenerationProvider {
  readonly name: string;
  generate(input: GenerateInput): GenerationDraft;
}

const philText =
  "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.";
const psalmText = "The LORD is my shepherd; I shall not want.";

function placeholderVerse(reference: string): string {
  const key = reference.trim().toLowerCase();
  if (key.startsWith("phil")) return philText;
  if (key.startsWith("ps")) return psalmText;
  return "Placeholder verse text.";
}

export class FakeGenerationProvider implements GenerationProvider {
  readonly name = "fake";

  generate(input: GenerateInput): GenerationDraft {
    const base = {
      title: "Steady Ground on a First Morning",
      hook: "Lorem ipsum placeholder hook for a new beginning.",
      sections: [
        "Placeholder section. A real provider will write this reflection later.",
        "Second placeholder section. No model was called.",
      ],
      takeaway:
        "Placeholder takeaway: dolor sit amet, one short line of encouragement.",
      cost_usd: 0,
      tokens_in: 0,
      tokens_out: 0,
      embedding: null,
    };
    if (input.verseMode && input.verseRefs.length > 0) {
      const first = input.verseRefs[0];
      const second = input.verseRefs[1] ?? first;
      return {
        ...base,
        verse_text: placeholderVerse(first),
        verse_ref: first,
        scriptures: [
          { reference: first, text: placeholderVerse(first) },
          { reference: second, text: placeholderVerse(second) },
        ],
      };
    }
    return {
      ...base,
      verse_text: philText,
      verse_ref: "Phil 4:6",
      scriptures: [
        { reference: "Philippians 4:6", text: philText },
        { reference: "Psalm 23:1", text: psalmText },
      ],
    };
  }
}

export function providerFromEnv(): GenerationProvider {
  const name = (Deno.env.get("GENERATION_PROVIDER") ?? "fake").toLowerCase();
  if (name !== "fake") {
    throw new Error(
      `GENERATION_PROVIDER=${name} is not implemented. Use fake, or add a provider later.`,
    );
  }
  return new FakeGenerationProvider();
}

export const scriptureAnchorReason = "Scripture refs are missing or unrelated";

// Placeholder copy. Wording and triggers are pending final approval.
export const defaultHelpNoteText =
  "If you're struggling, please reach out to a pastor, a trusted friend, or a doctor. In the US, call or text 988 any time.";

export const defaultHelpNoteTriggers = [
  "health",
  "illness",
  "grief",
  "depression",
  "anxiety",
  "abuse",
  "self-harm",
];

export type HelpNoteConfig = { helpNote: string; triggers: string[] };

export function helpNoteConfigFromEnv(): HelpNoteConfig {
  const text = Deno.env.get("HELP_NOTE")?.trim() ?? "";
  const listed = (Deno.env.get("HELP_NOTE_TRIGGERS") ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  return {
    helpNote: text || defaultHelpNoteText,
    triggers: listed.length > 0 ? listed : defaultHelpNoteTriggers,
  };
}

export function helpNoteFor(input: GenerateInput, config = helpNoteConfigFromEnv()): string | null {
  if (!config.helpNote.trim() || config.triggers.length === 0) return null;
  const haystack = fold(`${input.topic} ${input.lifeSituations.join(" ")}`);
  for (const trigger of config.triggers) {
    const needle = fold(trigger);
    if (!needle) continue;
    const pattern = new RegExp(`\\b${needle.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\b`);
    if (pattern.test(haystack)) return config.helpNote;
  }
  return null;
}

type ParsedRef = { book: string; chapter: number; start: number; end: number };

const bookAliases: Record<string, string> = {
  gen: "genesis",
  exo: "exodus",
  exod: "exodus",
  lev: "leviticus",
  num: "numbers",
  deut: "deuteronomy",
  jos: "joshua",
  josh: "joshua",
  jdg: "judges",
  judg: "judges",
  ru: "ruth",
  "1 sam": "1 samuel",
  "2 sam": "2 samuel",
  "1 kgs": "1 kings",
  "2 kgs": "2 kings",
  "1 chr": "1 chronicles",
  "2 chr": "2 chronicles",
  neh: "nehemiah",
  ps: "psalm",
  psa: "psalm",
  psalm: "psalm",
  psalms: "psalm",
  prov: "proverbs",
  eccl: "ecclesiastes",
  song: "song of solomon",
  isa: "isaiah",
  jer: "jeremiah",
  lam: "lamentations",
  ezek: "ezekiel",
  dan: "daniel",
  hos: "hosea",
  obad: "obadiah",
  mic: "micah",
  hab: "habakkuk",
  zeph: "zephaniah",
  hag: "haggai",
  zech: "zechariah",
  mal: "malachi",
  matt: "matthew",
  mt: "matthew",
  mk: "mark",
  lk: "luke",
  jn: "john",
  rom: "romans",
  "1 cor": "1 corinthians",
  "2 cor": "2 corinthians",
  gal: "galatians",
  eph: "ephesians",
  phil: "philippians",
  col: "colossians",
  "1 thess": "1 thessalonians",
  "2 thess": "2 thessalonians",
  "1 tim": "1 timothy",
  "2 tim": "2 timothy",
  tit: "titus",
  phlm: "philemon",
  heb: "hebrews",
  jas: "james",
  "1 pet": "1 peter",
  "2 pet": "2 peter",
  "1 jn": "1 john",
  "2 jn": "2 john",
  "3 jn": "3 john",
  rev: "revelation",
};

function parseRef(raw: string): ParsedRef | null {
  let text = raw.trim().toLowerCase().replaceAll(".", "").replace(/\s+/g, " ");
  text = text.replace(/\s+(esv|niv|kjv|nlt|nkjv|csb|nasb)$/, "");
  const match = text.match(/^(.*)\s+(\d+):(\d+)(?:-(\d+))?$/);
  if (!match) return null;
  const start = Number(match[3]);
  const end = Number(match[4] ?? match[3]);
  const chapter = Number(match[2]);
  if (!Number.isInteger(start) || !Number.isInteger(end) || end < start) return null;
  const book = bookAliases[match[1].trim()] ?? match[1].trim();
  if (!book) return null;
  return { book, chapter, start, end };
}

function overlaps(a: ParsedRef, b: ParsedRef): boolean {
  return a.book === b.book && a.chapter === b.chapter && a.start <= b.end && b.start <= a.end;
}

function fold(value: string): string {
  return value.toLowerCase().replaceAll("-", " ");
}

export class ScriptureAnchorException extends Error {
  constructor() {
    super(scriptureAnchorReason);
  }
}

// Rejects a draft whose Scripture refs are missing or unrelated.
// No other theology rule is applied.
export class ScriptureAnchorChecker {
  review(draft: GenerationDraft, input: GenerateInput): GenerationDraft {
    const callout = parseRef(draft.verse_ref);
    const quotes = draft.scriptures.map((quote) => parseRef(quote.reference));
    const structureOk = draft.verse_text.trim().length > 0 &&
      callout !== null &&
      draft.scriptures.length === 2 &&
      quotes.every((quote) => quote !== null) &&
      draft.scriptures.every((quote) => quote.text.trim().length > 0);
    if (!structureOk || !callout) throw new ScriptureAnchorException();

    if (input.verseMode) {
      const chosen = input.verseRefs.map(parseRef);
      if (chosen.length === 0 || chosen.some((ref) => ref === null)) {
        throw new ScriptureAnchorException();
      }
      const cited = [callout, ...(quotes as ParsedRef[])];
      const grounded = cited.every((ref) =>
        (chosen as ParsedRef[]).some((anchor) => overlaps(ref, anchor))
      );
      if (!grounded) throw new ScriptureAnchorException();
      return draft;
    }

    const calloutMatchesQuote = (quotes as ParsedRef[]).some((quote) => overlaps(callout, quote));
    if (!calloutMatchesQuote) throw new ScriptureAnchorException();
    return draft;
  }
}
