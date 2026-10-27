import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { DisabledEmbeddingProvider, KeywordTaggingProvider } from "./enrichment.js";
import { loadFixtureCards } from "./fixture.js";
import { NotionClient, readStatus, readTitle } from "./notion.js";
import { decide } from "./parse.js";
import { buildDevoTagLinks, logUnknownTags, savedKey, unknownTagSlugs } from "./devo-tags.js";
import { UPSERT_ON_CONFLICT, planImport, toUpsertRows, type ImportedDevo, type SourceCard } from "./pipeline.js";
import {
  SECTION_TAGS_ON_CONFLICT,
  SECTION_UPSERT_ON_CONFLICT,
  buildSectionTagLinks,
  buildSectionUpsertRows,
  planDevoSectionPrune,
} from "./sections.js";
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
  const imagesOnly = args.includes("--images-only");
  // --images-only still reads the feed so blank Banner properties can fall back.
  const rss = args.includes("--rss") || imagesOnly;
  const rssFixtureFlag = args.indexOf("--rss-fixture");
  const rssFixturePath = rssFixtureFlag >= 0 ? args[rssFixtureFlag + 1] : undefined;
  const rssUrlFlag = args.indexOf("--rss-url");
  const rssUrl = rssUrlFlag >= 0 ? args[rssUrlFlag + 1] : undefined;
  // A dry run of --rss, with no card fixture, reads the feed only.
  // --images-only reads Notion banners and headings, then updates image columns only.
  const rssOnlyDryRun =
    rss && dryRun && !fixturePath && !args.includes("--with-notion") && !imagesOnly;
  const loadNotion = !rssOnlyDryRun;

  let imported: ImportedDevo[] | undefined;
  if (loadNotion) {
    const cards = fixturePath
      ? await loadFixtureCards(path.resolve(fixturePath))
      : await cardsFromNotion(limit);
    const plan = await planImport(cards, {
      tagging: new KeywordTaggingProvider(),
      embedding: new DisabledEmbeddingProvider(),
    });
    imported = plan.imported;
    logBannerWarnings(plan.bannerWarnings);

    if (dryRun) {
      await mkdir(path.dirname(path.resolve(outPath)), { recursive: true });
      await writeFile(outPath, `${JSON.stringify(plan, null, 2)}\n`);
      console.log(
        `Dry run: ${plan.imported.length} devotions, ${plan.skipped.length} skipped, wrote ${outPath}`,
      );
    } else if (!imagesOnly) {
      await upsertNotionRows(plan.imported, plan.skipped.length);
    } else {
      console.log(
        `Read ${plan.imported.length} devotions for banner columns. Skipped ${plan.skipped.length}. Text was not written.`,
      );
    }
  }

  if (rss) {
    const reportPath = rssReportPath(args, outPath, loadNotion);
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
      ? [{
          editionDate: devo.edition_date,
          position: devo.position,
          title: devo.title,
          notionBannerUrl: devo.notion_banner_url,
          notionBannerAlt: devo.notion_banner_alt,
        }]
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
  logUnknownTags(unknownTagSlugs([
    ...imported.flatMap((devo) => devo.tags),
    ...imported.flatMap((devo) => (devo.sections ?? []).flatMap((section) => section.tags)),
  ], tagIds));
  const links = buildDevoTagLinks(imported, saved, tagIds);
  if (links.length > 0) {
    const { error: linkError } = await supabase
      .from("devo_tags")
      .upsert(links, { onConflict: "devo_id,tag_id" });
    if (linkError) throw linkError;
  }
  await upsertSections(supabase, imported, saved, tagIds);
  console.log(`Upserted ${rows.length} devotions on ${UPSERT_ON_CONFLICT}. Skipped ${skipped}.`);
}

async function upsertSections(
  supabase: ReturnType<typeof supabaseClient>,
  imported: ImportedDevo[],
  saved: Map<string, string>,
  tagIds: Map<string, string>,
) {
  const rows = [];
  for (const devo of imported) {
    const devoId = saved.get(savedKey(devo.notion_page_id, devo.position));
    if (!devoId) continue;
    rows.push(...buildSectionUpsertRows(devoId, devo.sections ?? []));
  }
  let savedSections: Array<{ id: string; devo_id: string; position: number }> = [];
  if (rows.length > 0) {
    const { data, error } = await supabase
      .from("devo_sections")
      .upsert(rows, { onConflict: SECTION_UPSERT_ON_CONFLICT })
      .select("id, devo_id, position");
    if (error) throw error;
    savedSections = (data ?? []) as Array<{ id: string; devo_id: string; position: number }>;
  }
  const byKey = new Map(savedSections.map((row) => [`${row.devo_id}:${row.position}`, row.id]));
  const tagged: Array<{ id: string; tags: string[] }> = [];
  for (const devo of imported) {
    const devoId = saved.get(savedKey(devo.notion_page_id, devo.position));
    if (!devoId) continue;
    for (const section of devo.sections ?? []) {
      const id = byKey.get(`${devoId}:${section.position}`);
      if (id) tagged.push({ id, tags: section.tags });
    }
    const keep = (devo.sections ?? []).map((section) => section.position);
    // Notion cards without sections must not wipe sections loaded from v6 content files.
    if (keep.length === 0) continue;
    const plan = planDevoSectionPrune(devo.sections);
    if (!plan.deleteIssued) continue;
    let removal = supabase.from("devo_sections").delete().eq("devo_id", devoId);
    if (keep.length > 0) {
      removal = removal.not("position", "in", plan.notIn);
    }
    const { error: removeError } = await removal;
    if (removeError) throw removeError;
  }
  for (const section of tagged) {
    const keepIds = section.tags
      .map((slug) => tagIds.get(slug))
      .filter((id): id is string => Boolean(id));
    let tagRemoval = supabase.from("section_tags").delete().eq("section_id", section.id);
    if (keepIds.length > 0) {
      tagRemoval = tagRemoval.not("tag_id", "in", `(${keepIds.join(",")})`);
    }
    const { error: tagRemoveError } = await tagRemoval;
    if (tagRemoveError) throw tagRemoveError;
  }
  const sectionLinks = buildSectionTagLinks(tagged, tagIds);
  if (sectionLinks.length > 0) {
    const { error } = await supabase
      .from("section_tags")
      .upsert(sectionLinks, { onConflict: SECTION_TAGS_ON_CONFLICT });
    if (error) throw error;
  }
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
  const counts = await countImageRows(supabase);
  console.log(`image_url filled ${counts.filled}, null ${counts.empty}`);
}

async function countImageRows(supabase: SupabaseClient): Promise<{ filled: number; empty: number }> {
  const filled = await supabase
    .from("devos")
    .select("id", { count: "exact", head: true })
    .not("image_url", "is", null);
  if (filled.error) throw filled.error;
  const empty = await supabase
    .from("devos")
    .select("id", { count: "exact", head: true })
    .is("image_url", null);
  if (empty.error) throw empty.error;
  return { filled: filled.count ?? 0, empty: empty.count ?? 0 };
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
