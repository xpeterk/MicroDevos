import { existsSync, readdirSync } from "node:fs";
import path from "node:path";
import dotenv from "dotenv";
import {
  readDayContent,
  buildV6SqlTransaction,
  type V6DayData,
} from "./loader.js";

// Load root .env if it exists
const rootEnv = path.resolve(process.cwd(), ".env");
if (existsSync(rootEnv)) {
  dotenv.config({ path: rootEnv });
}
const localEnv = path.resolve(process.cwd(), "tools/v6-load/.env");
if (existsSync(localEnv)) {
  dotenv.config({ path: localEnv });
}

const SUPABASE_PROJECT_ID = process.env.SUPABASE_PROJECT_ID || "ftvyiutgotrbtdbvdjje";
const SUPABASE_ACCESS_TOKEN = process.env.SUPABASE_ACCESS_TOKEN;
const SUPABASE_URL = process.env.SUPABASE_URL || `https://${SUPABASE_PROJECT_ID}.supabase.co`;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

export async function executeSqlViaManagementApi(query: string): Promise<any> {
  if (!SUPABASE_ACCESS_TOKEN) {
    throw new Error(
      "SUPABASE_ACCESS_TOKEN is required to execute SQL via the Supabase Management API. Set it in .env or the environment."
    );
  }

  const endpoint = `https://api.supabase.com/v1/projects/${SUPABASE_PROJECT_ID}/database/query`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_ACCESS_TOKEN}`,
    },
    body: JSON.stringify({ query }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Management API query failed (${response.status}): ${errorText}`);
  }

  return response.json();
}

export async function verifyEditionDate(date: string): Promise<{
  devoCount: number;
  sectionCount: number;
  hasEmptyTeaserOrPrayer: boolean;
  leftover4SectionRows: boolean;
  anonRestOk: boolean;
}> {
  const checkSql = `
    SELECT
      count(*)::int as devo_count,
      count(case when teaser = '' or prayer = '' then 1 end)::int as missing_teaser_prayer
    FROM public.devos
    WHERE edition_date = '${date}';

    SELECT
      d.position as devo_pos,
      count(s.id)::int as section_count
    FROM public.devos d
    LEFT JOIN public.devo_sections s ON s.devo_id = d.id
    WHERE d.edition_date = '${date}'
    GROUP BY d.position
    ORDER BY d.position;
  `;

  let devoCount = 0;
  let hasEmptyTeaserOrPrayer = false;
  let totalSections = 0;
  let leftover4SectionRows = false;

  if (SUPABASE_ACCESS_TOKEN) {
    const res = await executeSqlViaManagementApi(checkSql);
    // Parse result sets
    if (Array.isArray(res)) {
      if (res[0] && Array.isArray(res[0])) {
        devoCount = res[0][0]?.devo_count ?? 0;
        hasEmptyTeaserOrPrayer = (res[0][0]?.missing_teaser_prayer ?? 0) > 0;
      }
      if (res[1] && Array.isArray(res[1])) {
        for (const row of res[1]) {
          totalSections += row.section_count;
          if (row.section_count > 3) leftover4SectionRows = true;
        }
      }
    }
  }

  // Check anon REST read under RLS
  let anonRestOk = false;
  if (SUPABASE_ANON_KEY && SUPABASE_URL) {
    try {
      const restRes = await fetch(
        `${SUPABASE_URL}/rest/v1/devos?edition_date=eq.${date}&select=id,title,teaser,prayer,devo_sections(id,title,summary,image_url)`,
        {
          headers: {
            apikey: SUPABASE_ANON_KEY,
            Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
          },
        }
      );
      if (restRes.ok) {
        const rows = await restRes.json();
        anonRestOk = Array.isArray(rows) && rows.length > 0;
      }
    } catch {
      anonRestOk = false;
    }
  }

  return {
    devoCount,
    sectionCount: totalSections,
    hasEmptyTeaserOrPrayer,
    leftover4SectionRows,
    anonRestOk,
  };
}

export async function loadDay(
  contentRoot: string,
  date: string,
  options: { dryRun?: boolean } = {}
): Promise<{ success: boolean; skipped: boolean; reason?: string }> {
  console.log(`\n--- Loading v6 content for edition ${date} ---`);
  const data = readDayContent(contentRoot, date);
  if (!data) {
    const reason = `content files for ${date} not found in ${path.join(contentRoot, date)}`;
    console.log(`[SKIP] ${reason}`);
    return { success: true, skipped: true, reason };
  }

  if (data.devos.length === 0) {
    const reason = `no valid devotional data parsed for ${date}`;
    console.log(`[SKIP] ${reason}`);
    return { success: true, skipped: true, reason };
  }

  const sql = buildV6SqlTransaction(data);
  if (options.dryRun) {
    console.log(`[DRY-RUN] Generated SQL for ${date} (${sql.length} chars, ${data.devos.length} devos)`);
    return { success: true, skipped: false };
  }

  console.log(`Executing SQL transaction for ${date}...`);
  await executeSqlViaManagementApi(sql);
  console.log(`[SUCCESS] Transaction committed for ${date}.`);

  return { success: true, skipped: false };
}

async function main() {
  const args = process.argv.slice(2);
  let targetDate: string | undefined;
  let dryRun = false;
  let checkOnly = false;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--date" && args[i + 1]) {
      targetDate = args[++i];
    } else if (args[i] === "--dry-run") {
      dryRun = true;
    } else if (args[i] === "--check") {
      checkOnly = true;
    }
  }

  const contentRoot = path.resolve(process.cwd(), "content/v6");

  const datesToProcess = targetDate
    ? [targetDate]
    : ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"];

  if (checkOnly) {
    for (const d of datesToProcess) {
      console.log(`Checking status for ${d}...`);
      try {
        const check = await verifyEditionDate(d);
        console.log(`Date: ${d} | Devos: ${check.devoCount} | Sections: ${check.sectionCount} | Empty Teaser/Prayer: ${check.hasEmptyTeaserOrPrayer} | Leftover 4-sec: ${check.leftover4SectionRows} | Anon REST: ${check.anonRestOk}`);
      } catch (err: any) {
        console.warn(`Could not verify ${d}: ${err.message}`);
      }
    }
    return;
  }

  for (const date of datesToProcess) {
    try {
      await loadDay(contentRoot, date, { dryRun });
    } catch (err: any) {
      console.error(`Error loading ${date}: ${err.message}`);
    }
  }
}

if (process.argv[1] && process.argv[1].endsWith("index.ts")) {
  main().catch((err) => {
    console.error("v6-load failed:", err);
    process.exit(1);
  });
}
