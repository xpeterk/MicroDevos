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
  cost_usd: number;
  tokens_in: number;
  tokens_out: number;
  embedding: number[] | null;
};

export interface GenerationProvider {
  readonly name: string;
  generate(input: GenerateInput): GenerationDraft;
}

export class FakeGenerationProvider implements GenerationProvider {
  readonly name = "fake";

  generate(_input: GenerateInput): GenerationDraft {
    return {
      title: "Steady Ground on a First Morning",
      hook: "Lorem ipsum placeholder hook for a new beginning.",
      sections: [
        "Placeholder section. A real provider will write this reflection later.",
        "Second placeholder section. No model was called.",
      ],
      takeaway:
        "Placeholder takeaway: dolor sit amet, one short line of encouragement.",
      verse_text:
        "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.",
      verse_ref: "Phil 4:6",
      scriptures: [
        {
          reference: "Philippians 4:6",
          text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.",
        },
        {
          reference: "Psalm 23:1",
          text: "The LORD is my shepherd; I shall not want.",
        },
      ],
      cost_usd: 0,
      tokens_in: 0,
      tokens_out: 0,
      embedding: null,
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

// TODO: the owner defines the guardrails. This check passes every draft through.
export interface SafetyChecker {
  review(draft: GenerationDraft): Promise<GenerationDraft>;
}

export class PassThroughSafetyChecker implements SafetyChecker {
  async review(draft: GenerationDraft): Promise<GenerationDraft> {
    return draft;
  }
}
