import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { SourceCard } from "./pipeline.js";

type FixtureFile = {
  cards: Array<{
    id: string;
    properties: Record<string, unknown>;
    markdown?: string;
    markdownFile?: string;
  }>;
};

export async function loadFixtureCards(file: URL | string): Promise<SourceCard[]> {
  const filePath = typeof file === "string" ? file : fileURLToPath(file);
  const raw = JSON.parse(await readFile(filePath, "utf8")) as FixtureFile;
  if (!Array.isArray(raw.cards)) throw new Error("Fixture must be { cards: [...] }");
  const directory = path.dirname(filePath);
  const cards: SourceCard[] = [];
  for (const card of raw.cards) {
    let markdown = card.markdown ?? "";
    if (card.markdownFile) {
      markdown = await readFile(path.join(directory, card.markdownFile), "utf8");
    }
    if (!card.id || !card.properties) throw new Error("Each fixture card needs id and properties");
    cards.push({ id: card.id, properties: card.properties, markdown });
  }
  return cards;
}
