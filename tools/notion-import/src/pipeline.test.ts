import assert from "node:assert/strict";
import test from "node:test";
import { FakeEmbeddingProvider, FakeTaggingProvider } from "./enrichment.js";
import { loadFixtureCards } from "./fixture.js";
import { UPSERT_ON_CONFLICT, planImport, toUpsertRows } from "./pipeline.js";

const fixturePath = new URL("../fixtures/sample-cards.json", import.meta.url);

test("imports a real card and skips ideas, AI-ideas, prompts, and missing editions", async () => {
  const cards = await loadFixtureCards(fixturePath);
  const fakeTags = new FakeTaggingProvider(["peace"]);
  const fakeVectors = new FakeEmbeddingProvider([0.5, 0.25]);
  const plan = await planImport(cards, { tagging: fakeTags, embedding: fakeVectors });

  assert.equal(plan.imported.length, 1);
  assert.deepEqual(
    plan.skipped.map((card) => card.reason).sort(),
    ["no edition link", "non-devo page", "status is AI-Ideas", "status is Ideas"].sort(),
  );

  const devo = plan.imported[0];
  assert.equal(devo.notion_page_id, "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1");
  assert.equal(devo.title, "A Refuge That Does Not Move");
  assert.equal(devo.position, 3);
  assert.equal(devo.edition_date, "2026-10-16");
  assert.equal(devo.status, "Archive");
  assert.equal(devo.stars, 3);
  assert.equal(devo.source_url, "https://example.com/refuge");
  assert.equal(devo.hook, "A refuge is a person, and he is already here.");
  assert.equal(devo.takeaway, "Today, say the verse once before the next hard conversation.");
  assert.equal(devo.verse_ref, "Psalm 46:1");
  assert.match(devo.verse_text, /refuge and strength/);
  assert.equal(
    devo.edition_url,
    "https://microdevos.substack.com/p/micro-devos-friday-october-16-2026",
  );
  assert.equal(devo.body_md.includes("VERSE"), false);
  assert.deepEqual(devo.tags, ["peace"]);
  assert.deepEqual(devo.embedding, [0.5, 0.25]);
  assert.equal(fakeVectors.calls.length, 1);

  const [row] = toUpsertRows(plan.imported);
  assert.equal(row.notion_page_id, devo.notion_page_id);
  assert.equal(row.position, 3);
  assert.equal(UPSERT_ON_CONFLICT, "notion_page_id,position");
});

test("the default providers suggest local tags and leave embeddings empty", async () => {
  const cards = await loadFixtureCards(fixturePath);
  const plan = await planImport(cards);
  const devo = plan.imported[0];
  assert.equal(devo.embedding, null);
  assert.ok(devo.tags.includes("fear"));
  assert.ok(devo.tags.includes("peace"));
  assert.ok(devo.tags.includes("prayer"));
  assert.equal("embedding" in toUpsertRows(plan.imported)[0], false);
});
