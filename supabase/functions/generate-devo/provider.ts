// Generation is behind this interface. The default is a fake provider.
// A later real provider implements GenerationProvider and is selected with
// GENERATION_PROVIDER. Do not add a model API key here.

export type Scripture = { reference: string; text: string };

export type StructuredSection = {
  id: string;
  devo_id: string;
  position: number;
  title: string;
  summary: string;
  minutes: number;
  verse_ref: string;
  verse_text: string;
  body: string;
  tags: string[];
};

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
  structured_sections?: StructuredSection[];
  takeaway: string;
  verse_text: string;
  verse_ref: string;
  scriptures: Scripture[];
  one_minute_text?: string | null;
  one_minute_verse_ref?: string | null;
  one_minute_verse_text?: string | null;
  one_minute_today?: string | null;
  prayer?: string | null;
  help_note?: string | null;
  cost_usd: number;
  tokens_in: number;
  tokens_out: number;
  embedding: number[] | null;
};

export interface GenerationProvider {
  readonly name: string;
  generate(input: GenerateInput): Promise<GenerationDraft> | GenerationDraft;
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
    const vRef = input.verseMode && input.verseRefs.length > 0 ? input.verseRefs[0] : "Philippians 4:6-7";
    const vText = placeholderVerse(vRef);
    const secondRef = input.verseMode && input.verseRefs.length > 1 ? input.verseRefs[1] : "Psalm 23:1";
    const secondText = placeholderVerse(secondRef);

    const oneMin =
      "When uncertainty rises, fear is quick to narrate the worst outcomes. Yet Scripture invites us into a steadfast peace that is not rooted in circumstances, but in the character of our heavenly Father. In every trial, God remains an unwavering refuge. When we bring our anxieties to Him in prayer, He guards our hearts with peace that surpasses human understanding. Entrust your steps to Him today, for His faithfulness endures through every storm.";

    const prayer =
      "🙏 Heavenly Father, anchor my heart in Your unfailing love today and grant me Your surpassing peace in every uncertainty. Amen.";

    const structured: StructuredSection[] = [
      {
        id: "s1",
        devo_id: "fake",
        position: 1,
        title: "Naming the Uncertainty",
        summary: "Facing fear with an open heart before God.",
        minutes: 1,
        verse_ref: vRef,
        verse_text: vText,
        body:
          "We often hesitate to bring our worries into prayer until we think we have them sorted out. But God welcomes us as we are, inviting us to lay every concern before His throne of grace.",
        tags: ["peace", "trust"],
      },
      {
        id: "s2",
        devo_id: "fake",
        position: 2,
        title: "The Peace That Guards",
        summary: "God’s peace stands as a vigilant guardian over the restless soul.",
        minutes: 1,
        verse_ref: "Isaiah 26:3",
        verse_text:
          "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
        body:
          "The peace of God does not merely soothe; it acts as a fortress around our thoughts. In Christ Jesus, we are held securely even when the ground around us shakes.",
        tags: ["prayer", "comfort"],
      },
      {
        id: "s3",
        devo_id: "fake",
        position: 3,
        title: "Walking in Quiet Confidence",
        summary: "Stepping forward one moment at a time in obedience and faith.",
        minutes: 1,
        verse_ref: secondRef,
        verse_text: secondText,
        body:
          "Faith does not require knowing what next year holds; it only asks that we trust the One who holds tomorrow. Lay your anxieties down and walk forward in His light.",
        tags: ["faith", "hope"],
      },
    ];

    return {
      title: "Steady Ground on a First Morning",
      hook: "When life feels unsteady, God’s peace remains our immovable anchor.",
      sections: structured.map((s) => s.body),
      structured_sections: structured,
      takeaway: "Before reacting to worry, pause and present your requests to God with thanksgiving.",
      verse_text: vText,
      verse_ref: vRef,
      scriptures: [
        { reference: vRef, text: vText },
        { reference: secondRef, text: secondText },
      ],
      one_minute_text: oneMin,
      one_minute_today: "Take one quiet minute to name your deepest worry and surrender it to God.",
      one_minute_verse_ref: vRef,
      one_minute_verse_text: vText,
      prayer,
      cost_usd: 0,
      tokens_in: 0,
      tokens_out: 0,
      embedding: null,
    };
  }
}

export class GeminiGenerationProvider implements GenerationProvider {
  readonly name = "gemini";
  constructor(private apiKey: string, private model = "gemini-2.5-flash") {}

  async generate(input: GenerateInput): Promise<GenerationDraft> {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`;
    const contextBits = [
      input.ageRange ? `Age: ${input.ageRange}` : "",
      input.lifeSituations.length > 0 ? `Life context: ${input.lifeSituations.join(", ")}` : "",
      input.bibleVersion ? `Translation: ${input.bibleVersion}` : "",
    ].filter(Boolean);

    const prompt = `Devotional topic: ${input.topic || (input.verseRefs.join(", "))}
Anchor verses: ${input.verseRefs.join(", ")}
Writing style: ${input.styleKey}
Reader context: ${contextBits.join("; ")}

Write a rich, orthodox, warm, biblically grounded Christian micro-devotional tailored to this reader.
Format requirements:
1. "title": Engaging, evocative title (under 8 words).
2. "hook": One memorable hook sentence capturing the core theme.
3. "takeaway": One concise sentence takeaway.
4. "verse_ref": Primary Scripture reference (e.g. "Philippians 4:6-7").
5. "verse_text": The full Scripture text for the reference.
6. "one_minute_text": Exactly one paragraph of ~140 to 160 words summarizing the whole devotion clearly.
7. "one_minute_today": A practical action/prayer takeaway sentence.
8. "one_minute_verse_ref": Scripture reference for the 1-minute devotion.
9. "one_minute_verse_text": The Scripture text for that reference.
10. "sections": An array of exactly 3 sequential sections that walk through the devotion. Each section MUST have:
    - "title": Plain title without numbering.
    - "summary": 1 short sentence summarizing this section.
    - "minutes": Integer reading time (1 or 2).
    - "verse_ref": A Scripture reference supporting this section.
    - "verse_text": The full verse text for this section.
    - "body": 1-2 rich, thoughtful paragraphs of reflection.
11. "prayer": A warm, heartfelt closing prayer sentence.
12. "scriptures": An array of exactly 2 ScriptureQuote objects with "reference" and "text".

Return strictly a valid JSON object matching these keys.`;

    try {
      const resp = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { responseMimeType: "application/json", temperature: 0.7 },
        }),
      });
      if (resp.ok) {
        const data = await resp.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text) {
          const parsed = JSON.parse(text);
          const vRef = parsed.verse_ref || (input.verseRefs[0] ?? "Philippians 4:6-7");
          const vText = parsed.verse_text || philText;
          const secs = (parsed.sections || []).map((s: any, i: number): StructuredSection => ({
            id: `s${i + 1}`,
            devo_id: "gen",
            position: i + 1,
            title: s.title || `Part ${i + 1}`,
            summary: s.summary || "",
            minutes: Number(s.minutes) || 1,
            verse_ref: s.verse_ref || vRef,
            verse_text: s.verse_text || vText,
            body: s.body || "",
            tags: [],
          }));

          const rawScriptures = parsed.scriptures || [];
          let scriptures: Scripture[] = rawScriptures;
          if (scriptures.length < 2) {
            scriptures = [
              { reference: vRef, text: vText },
              { reference: secs[1]?.verse_ref || "Psalm 23:1", text: secs[1]?.verse_text || psalmText },
            ];
          }

          return {
            title: parsed.title || "Steady Ground on a First Morning",
            hook: parsed.hook || "God meets us in our deepest need.",
            sections: secs.map((s: StructuredSection) => s.body),
            structured_sections: secs,
            takeaway: parsed.takeaway || "Trust the Lord with all your heart.",
            verse_text: vText,
            verse_ref: vRef,
            scriptures,
            one_minute_text: parsed.one_minute_text || null,
            one_minute_verse_ref: parsed.one_minute_verse_ref || vRef,
            one_minute_verse_text: parsed.one_minute_verse_text || vText,
            one_minute_today: parsed.one_minute_today || null,
            prayer: parsed.prayer || null,
            cost_usd: 0,
            tokens_in: 0,
            tokens_out: 0,
            embedding: null,
          };
        }
      }
    } catch (_) {
      // fallback
    }
    return new FakeGenerationProvider().generate(input);
  }
}

export function providerFromEnv(): GenerationProvider {
  const geminiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  const name = (Deno.env.get("GENERATION_PROVIDER") ?? (geminiKey ? "gemini" : "fake")).toLowerCase();
  if (name === "gemini" && geminiKey) {
    return new GeminiGenerationProvider(geminiKey);
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
