import assert from "node:assert/strict";
import test from "node:test";
import { buildDevoTagLinks, devoTagUpsertStatement, savedKey, unknownTagSlugs } from "./devo-tags.js";

test("tag links follow the saved devotion and skip unknown slugs", () => {
  const saved = new Map([[savedKey("page-1", 3), "devo-id"]]);
  const tagIds = new Map([
    ["fear", "tag-fear"],
    ["peace", "tag-peace"],
  ]);
  const links = buildDevoTagLinks(
    [{ notion_page_id: "page-1", position: 3, tags: ["fear", "missing", "peace"] }],
    saved,
    tagIds,
  );
  assert.deepEqual(links, [
    { devo_id: "devo-id", tag_id: "tag-fear" },
    { devo_id: "devo-id", tag_id: "tag-peace" },
  ]);
  const statement = devoTagUpsertStatement(links);
  assert.match(statement.text, /on conflict \(devo_id, tag_id\)/);
  assert.deepEqual(statement.values, ["devo-id", "tag-fear", "devo-id", "tag-peace"]);
  assert.deepEqual(unknownTagSlugs(["fear", "missing", "peace", "missing"], tagIds), ["missing"]);
});
