import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createClient } from "@supabase/supabase-js";
import { NotionClient, readDate, readStars, readStatus, readTitle, readUrl } from "./notion.js";
import { decide, parseDevoMarkdown } from "./parse.js";
import type { ParsedDevo } from "./types.js";

const DEFAULT_DATA_SOURCE = "515d5d5d-b81b-4751-a025-d2c0734e3f60";

type Skip = { id: string; title: string; reason: string };

async function main() {
  await loadEnv(path.resolve(".env"));
  await loadEnv(path.resolve("tools/notion-import/.env"));

  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const outFlag = args.indexOf("--out");
  const outPath = outFlag >= 0 ? args[outFlag + 1] : "tools/notion-import/out/devos.json";
  const limitFlag = args.indexOf("--limit");
  const limit = limitFlag >= 0 ? Number(args[limitFlag + 1]) : Infinity;

  const token = process.env.NOTION_TOKEN;
  if (!token) throw new Error("NOTION_TOKEN is required");
  const dataSourceId = process.env.NOTION_DATA_SOURCE_ID || DEFAULT_DATA_SOURCE;
  const notion = new NotionClient(token, dataSourceId);
  const pages = await notion.queryPages();

  const imported: ParsedDevo[] = [];
  const skipped: Skip[] = [];
  let seen = 0;

  for (const page of pages) {
    if (seen >= limit) break;
    const title = readTitle(page.properties);
    const status = readStatus(page.properties);
    const normalized = (status ?? "").toLowerCase();
    if (normalized === "ideas" || normalized === "ai-ideas" || title.trim().toLowerCase() === "prompt") {
      skipped.push({
        id: page.id,
        title,
        reason: normalized === "ideas" || normalized === "ai-ideas" ? `status is ${status}` : "non-devo page",
      });
      continue;
    }

    const markdown = await notion.pageMarkdown(page.id);
    const decision = decide({ status, title, markdown });
    if (!decision.shouldImport) {
      skipped.push({ id: page.id, title, reason: decision.reason });
      continue;
    }
    const devos = parseDevoMarkdown(markdown, {
      title,
      status,
      editionDate: readDate(page.properties),
      stars: readStars(page.properties),
      sourceUrl: readUrl(page.properties),
      notionPageId: page.id,
    });
    if (devos.length === 0) {
      skipped.push({ id: page.id, title, reason: "parser found no devotions" });
      continue;
    }
    imported.push(...devos);
    seen += 1;
    await new Promise((resolve) => setTimeout(resolve, 350));
  }

  const payload = { imported, skipped };
  if (dryRun) {
    await mkdir(path.dirname(outPath), { recursive: true });
    await writeFile(outPath, `${JSON.stringify(payload, null, 2)}\n`);
    console.log(`Dry run: ${imported.length} devotions, ${skipped.length} skipped, wrote ${outPath}`);
    return;
  }

  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required");
  const supabase = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const rows = imported.map((devo) => ({
    title: devo.title,
    hook: devo.hook,
    body_md: devo.body_md,
    takeaway: devo.takeaway,
    verse_text: devo.verse_text,
    verse_ref: devo.verse_ref,
    scriptures: devo.scriptures,
    source_url: devo.source_url,
    edition_date: devo.edition_date,
    edition_url: devo.edition_url,
    position: devo.position,
    stars: devo.stars,
    status: (devo.status ?? "published").toLowerCase(),
    notion_page_id: devo.notion_page_id,
    published_at: new Date().toISOString(),
  }));
  const { error } = await supabase.from("devos").upsert(rows, {
    onConflict: "notion_page_id,position",
  });
  if (error) throw error;
  console.log(`Upserted ${rows.length} devotions. Skipped ${skipped.length}.`);
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
