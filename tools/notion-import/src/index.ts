import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { DisabledEmbeddingProvider, KeywordTaggingProvider } from "./enrichment.js";
import { loadFixtureCards } from "./fixture.js";
import { NotionClient, readStatus, readTitle } from "./notion.js";
import { decide } from "./parse.js";
import { buildDevoTagLinks, savedKey } from "./devo-tags.js";
import { UPSERT_ON_CONFLICT, planImport, toUpsertRows, type ImportedDevo, type SourceCard } from "./pipeline.js";
import {
  bannerWritePayload,
  formatBannerReport,
  loadFeedXml,
  logBannerWarnings,
  matchBanners,
  parseRssFeed,
  type BannerUpdate,
  type DevoSlot,
} from "./rss.js";

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
  const rss = args.includes("--rss");
  const imagesOnly = args.includes("--images-only");
  const rssFixtureFlag = args.indexOf("--rss-fixture");
  const rssFixturePath = rssFixtureFlag >= 0 ? args[rssFixtureFlag + 1] : undefined;
  const rssUrlFlag = args.indexOf("--rss-url");
  const rssUrl = rssUrlFlag >= 0 ? args[rssUrlFlag + 1] : undefined;
  // A dry run of --rss, with no card fixture, reads the feed only.
  // npm run import -- --rss still imports Notion text, then sets banner columns.
  const withNotion = !imagesOnly && (Boolean(fixturePath) || args.includes("--with-notion") || !rss || !dryRun);

  let imported: ImportedDevo[] | undefined;
  if (withNotion) {
    const cards = fixturePath
      ? await loadFixtureCards(path.resolve(fixturePath))
      : await cardsFromNotion(limit);
    const plan = await planImport(cards, {
      tagging: new KeywordTaggingProvider(),
      embedding: new DisabledEmbeddingProvider(),
    });
    imported = plan.imported;

    if (dryRun) {
      await mkdir(path.dirname(path.resolve(outPath)), { recursive: true });
      await writeFile(outPath, `${JSON.stringify(plan, null, 2)}\n`);
      console.log(
        `Dry run: ${plan.imported.length} devotions, ${plan.skipped.length} skipped, wrote ${outPath}`,
      );
    } else {
      await upsertNotionRows(plan.imported, plan.skipped.length);
    }
  }

  if (rss) {
    const reportPath = rssReportPath(args, outPath, withNotion);
    await runRssStep({
      dryRun,
      fixturePath: rssFixturePath ? path.resolve(rssFixturePath) : undefined,
      url: rssUrl,
      reportPath,
      devos: imported ? slotsFromImported(imported) : [],
    });
  }
}

function rssReportPath(args: string[], outPath: string, withNotion: boolean): string {
  const rssOutFlag = args.indexOf("--rss-out");
  if (rssOutFlag >= 0) return args[rssOutFlag + 1];
  if (!withNotion && args.includes("--out")) return outPath;
  return "out/rss-banners.json";
}

function slotsFromImported(imported: ImportedDevo[]): DevoSlot[] {
  return imported.flatMap((devo) =>
    devo.edition_date
      ? [{ editionDate: devo.edition_date, position: devo.position, title: devo.title }]
      : [],
  );
}

async function upsertNotionRows(imported: ImportedDevo[], skipped: number) {
  const supabase = supabaseClient();
  const rows = toUpsertRows(imported);
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
  const links = buildDevoTagLinks(imported, saved, tagIds);
  if (links.length > 0) {
    const { error: linkError } = await supabase
      .from("devo_tags")
      .upsert(links, { onConflict: "devo_id,tag_id" });
    if (linkError) throw linkError;
  }
  console.log(`Upserted ${rows.length} devotions on ${UPSERT_ON_CONFLICT}. Skipped ${skipped}.`);
}

async function runRssStep(options: {
  dryRun: boolean;
  fixturePath?: string;
  url?: string;
  reportPath: string;
  devos: DevoSlot[];
}) {
  const { xml, source } = await loadFeedXml({
    fixturePath: options.fixturePath,
    url: options.url,
    readFile: (file) => readFile(file, "utf8"),
  });
  const editions = parseRssFeed(xml);
  const plan = matchBanners(editions, options.devos);
  console.log(formatBannerReport(source, editions));
  logBannerWarnings(plan.warnings);
  if (options.devos.length > 0) {
    const matched = plan.updates.filter((update) => update.imageUrl).length;
    const missed = plan.updates.filter((update) => !update.imageUrl).length;
    console.log(`Notion rows in this run: ${matched} banners matched, ${missed} left null`);
  }

  if (options.dryRun) {
    await mkdir(path.dirname(path.resolve(options.reportPath)), { recursive: true });
    await writeFile(
      options.reportPath,
      `${JSON.stringify({ source, editions, warnings: plan.warnings, updates: plan.updates }, null, 2)}\n`,
    );
    console.log(`RSS dry run wrote ${options.reportPath}`);
    return;
  }

  const supabase = supabaseClient();
  let written = 0;
  for (const update of plan.updates) {
    const count = await writeBanner(supabase, update);
    if (count === 0 && update.imageUrl) {
      console.warn(
        `warning: no devo row for ${update.editionDate} position ${update.position}; image_url left null`,
      );
    } else {
      written += count;
    }
  }
  console.log(`Set image_url and image_alt on ${written} devotions. Notion text was not changed.`);
}

async function writeBanner(supabase: SupabaseClient, update: BannerUpdate): Promise<number> {
  const { data, error } = await supabase
    .from("devos")
    .update(bannerWritePayload(update))
    .eq("edition_date", update.editionDate)
    .eq("position", update.position)
    .select("id");
  if (error) throw error;
  return data?.length ?? 0;
}

function supabaseClient() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
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
