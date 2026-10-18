import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import { DisabledEmbeddingProvider, KeywordTaggingProvider } from "./enrichment.js";
import { loadFixtureCards } from "./fixture.js";
import { NotionClient, readStatus, readTitle } from "./notion.js";
import { decide } from "./parse.js";
import { buildDevoTagLinks, savedKey } from "./devo-tags.js";
import { UPSERT_ON_CONFLICT, planImport, toUpsertRows, type SourceCard } from "./pipeline.js";

const DEFAULT_DATA_SOURCE = "515d5d5d-b81b-4751-a025-d2c0734e3f60";

async function main() {
  await loadEnv(path.resolve(".env"));
  await loadEnv(path.resolve("tools/notion-import/.env"));

  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const outFlag = args.indexOf("--out");
  const outPath = outFlag >= 0 ? args[outFlag + 1] : "out/devos.json";
  const limitFlag = args.indexOf("--limit");
  const limit = limitFlag >= 0 ? Number(args[limitFlag + 1]) : Infinity;
  const fixtureFlag = args.indexOf("--fixture");
  const fixturePath = fixtureFlag >= 0 ? args[fixtureFlag + 1] : undefined;

  const cards = fixturePath
    ? await loadFixtureCards(path.resolve(fixturePath))
    : await cardsFromNotion(limit);

  const plan = await planImport(cards, {
    tagging: new KeywordTaggingProvider(),
    embedding: new DisabledEmbeddingProvider(),
  });

  if (dryRun) {
    await mkdir(path.dirname(path.resolve(outPath)), { recursive: true });
    await writeFile(outPath, `${JSON.stringify(plan, null, 2)}\n`);
    console.log(
      `Dry run: ${plan.imported.length} devotions, ${plan.skipped.length} skipped, wrote ${outPath}`,
    );
    return;
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
  const supabase = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const rows = toUpsertRows(plan.imported);
  const { data, error } = await supabase
    .from("devos")
    .upsert(rows, { onConflict: UPSERT_ON_CONFLICT })
    .select("id, notion_page_id, position");
  if (error) throw error;

  const saved = new Map(
    (data ?? []).map((row) => [savedKey(row.notion_page_id as string | null, row.position as number), row.id as string]),
  );
  const { data: tagRows, error: tagError } = await supabase.from("tags").select("id, slug");
  if (tagError) throw tagError;
  const tagIds = new Map((tagRows ?? []).map((tag) => [tag.slug as string, tag.id as string]));
  const links = buildDevoTagLinks(plan.imported, saved, tagIds);
  if (links.length > 0) {
    const { error: linkError } = await supabase
      .from("devo_tags")
      .upsert(links, { onConflict: "devo_id,tag_id" });
    if (linkError) throw linkError;
  }
  console.log(
    `Upserted ${rows.length} devotions on ${UPSERT_ON_CONFLICT}. Skipped ${plan.skipped.length}.`,
  );
}

async function cardsFromNotion(limit: number): Promise<SourceCard[]> {
  const token = process.env.NOTION_TOKEN;
  if (!token) {
    throw new Error(
      "NOTION_TOKEN is required to read Notion. For a local dry run with no token: npm run import -- --dry-run --fixture fixtures/sample-cards.json",
    );
  }
  const dataSourceId = process.env.NOTION_DATA_SOURCE_ID || DEFAULT_DATA_SOURCE;
  const notion = new NotionClient(token, dataSourceId);
  const pages = await notion.queryPages();
  const cards: SourceCard[] = [];
  let imported = 0;

  for (const page of pages) {
    if (imported >= limit) break;
    const title = readTitle(page.properties);
    const status = readStatus(page.properties);
    const normalized = (status ?? "").toLowerCase();
    if (normalized === "ideas" || normalized === "ai-ideas" || title.trim().toLowerCase() === "prompt") {
      cards.push({ id: page.id, properties: page.properties, markdown: "" });
      continue;
    }
    const markdown = await notion.pageMarkdown(page.id);
    cards.push({ id: page.id, properties: page.properties, markdown });
    if (decide({ status, title, markdown }).shouldImport) imported += 1;
    await new Promise((resolve) => setTimeout(resolve, 350));
  }
  return cards;
}

async function loadEnv(file: string) {
  try {
    const text = await readFile(file, "utf8");
    for (const line of text.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq < 0) continue;
      const name = trimmed.slice(0, eq).trim();
      const value = trimmed.slice(eq + 1).trim().replace(/^['"]|['"]$/g, "");
      if (!process.env[name]) process.env[name] = value;
    }
  } catch {
    // Missing env files are fine. The shell can export the variables instead.
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
