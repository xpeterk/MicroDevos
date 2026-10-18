import { Client } from "pg";
import { DisabledEmbeddingProvider, KeywordTaggingProvider } from "./enrichment.js";
import { buildDevoTagLinks, devoTagUpsertStatement, savedKey } from "./devo-tags.js";
import { loadFixtureCards } from "./fixture.js";
import { planImport, toUpsertRows } from "./pipeline.js";

const fixture = new URL("../fixtures/sample-cards.json", import.meta.url);

async function main() {
  const client = new Client({
    host: process.env.PGHOST ?? "/var/run/postgresql",
    database: process.env.PGDATABASE ?? "micro_devos_test",
    user: process.env.PGUSER ?? "postgres",
  });
  await client.connect();
  try {
    const cards = await loadFixtureCards(fixture);
    const plan = await planImport(cards, {
      tagging: new KeywordTaggingProvider(),
      embedding: new DisabledEmbeddingProvider(),
    });
    if (plan.imported.length !== 1) {
      throw new Error(`expected 1 imported devotion, got ${plan.imported.length}`);
    }

    const row = toUpsertRows(plan.imported)[0];
    const saved = await client.query<{ id: string; notion_page_id: string; position: number }>(
      `insert into public.devos (
         title, hook, body_md, takeaway, verse_text, verse_ref, scriptures,
         source_url, edition_date, edition_url, position, stars, status,
         notion_page_id, published_at
       ) values (
         $1, $2, $3, $4, $5, $6, $7::jsonb,
         $8, $9::date, $10, $11, $12, $13,
         $14, $15::timestamptz
       )
       on conflict (notion_page_id, position) do update set
         title = excluded.title,
         hook = excluded.hook,
         body_md = excluded.body_md,
         takeaway = excluded.takeaway,
         verse_text = excluded.verse_text,
         verse_ref = excluded.verse_ref,
         scriptures = excluded.scriptures,
         source_url = excluded.source_url,
         edition_date = excluded.edition_date,
         edition_url = excluded.edition_url,
         stars = excluded.stars,
         status = excluded.status,
         published_at = excluded.published_at
       returning id, notion_page_id, position`,
      [
        row.title,
        row.hook,
        row.body_md,
        row.takeaway,
        row.verse_text,
        row.verse_ref,
        JSON.stringify(row.scriptures),
        row.source_url,
        row.edition_date,
        row.edition_url,
        row.position,
        row.stars,
        row.status,
        row.notion_page_id,
        row.published_at,
      ],
    );

    const savedIds = new Map(
      saved.rows.map((item) => [savedKey(item.notion_page_id, item.position), item.id]),
    );
    const tags = await client.query<{ id: string; slug: string }>("select id, slug from public.tags");
    const tagIds = new Map(tags.rows.map((tag) => [tag.slug, tag.id]));
    const links = buildDevoTagLinks(plan.imported, savedIds, tagIds);
    const expected = ["fear", "peace", "prayer"];
    const linkedSlugs = links
      .map((link) => tags.rows.find((tag) => tag.id === link.tag_id)?.slug)
      .filter((slug): slug is string => Boolean(slug))
      .sort();
    if (linkedSlugs.join(",") !== expected.join(",")) {
      throw new Error(`expected tags ${expected.join(",")}, got ${linkedSlugs.join(",")}`);
    }

    const statement = devoTagUpsertStatement(links);
    await client.query(statement.text, statement.values);
    await client.query(statement.text, statement.values);

    const count = await client.query<{ n: string; slugs: string[] }>(
      `select count(*)::text as n,
              array_agg(t.slug order by t.slug) as slugs
       from public.devo_tags dt
       join public.tags t on t.id = dt.tag_id
       where dt.devo_id = $1`,
      [saved.rows[0].id],
    );
    if (count.rows[0].n !== "3") {
      throw new Error(`expected 3 devo_tags rows after a second upsert, got ${count.rows[0].n}`);
    }
    if (count.rows[0].slugs.join(",") !== expected.join(",")) {
      throw new Error(`stored slugs ${count.rows[0].slugs.join(",")} do not match ${expected.join(",")}`);
    }
    console.log(
      `devo_tags upsert wrote ${count.rows[0].slugs.join(", ")} for ${row.notion_page_id} position ${row.position}`,
    );
  } finally {
    await client.end();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
