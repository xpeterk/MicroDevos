export interface EmbeddingProvider {
  readonly name: string;
  readonly configured: boolean;
  embed(text: string): Promise<number[] | null>;
}

/** Leaves the embedding column empty. This milestone never calls a model. */
export class DisabledEmbeddingProvider implements EmbeddingProvider {
  readonly name = "disabled";
  readonly configured = false;

  async embed(_text: string): Promise<null> {
    return null;
  }
}

/** Test double. Records the text and returns a fixed vector. */
export class FakeEmbeddingProvider implements EmbeddingProvider {
  readonly name = "fake";
  readonly configured = true;
  readonly calls: string[] = [];

  constructor(private readonly vector: number[] = [0.2, 0.4, 0.6, 0.8]) {}

  async embed(text: string): Promise<number[]> {
    this.calls.push(text);
    return this.vector;
  }
}

export interface TaggingProvider {
  readonly name: string;
  suggestTags(text: string, catalog: string[]): string[];
}

export const SEED_TAG_SLUGS = [
  "courage",
  "anxiety",
  "fear",
  "hope",
  "peace",
  "gratitude",
  "grief",
  "trust",
  "prayer",
  "rest",
  "scripture",
  "waiting",
  "perseverance",
  "identity",
  "work",
  "family",
];

/** Whole-word match against the tag catalog. No network. */
export class KeywordTaggingProvider implements TaggingProvider {
  readonly name = "keyword";

  suggestTags(text: string, catalog: string[]): string[] {
    return catalog.filter((slug) => new RegExp(`\\b${escapeRegExp(slug)}\\b`, "i").test(text));
  }
}

export class FakeTaggingProvider implements TaggingProvider {
  readonly name = "fake";
  readonly calls: string[] = [];

  constructor(private readonly tags: string[]) {}

  suggestTags(text: string, catalog: string[]): string[] {
    this.calls.push(text);
    return this.tags.filter((tag) => catalog.includes(tag));
  }
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
