import assert from "node:assert/strict";
import test from "node:test";
import { parseDevoMarkdown } from "./parse.js";
import {
  SECTION_UPSERT_ON_CONFLICT,
  buildSectionTagLinks,
  buildSectionUpsertRows,
} from "./sections.js";

const card = `
**At a Glance**
Come near before you feel ready.

[Wednesday edition](https://microdevos.substack.com/p/sample)

## 8 · Come Near Before You Feel Ready

Some of us wait to pray until we feel worthy of the conversation.

## App Sections

### Come Before You Feel Worthy
Summary: The throne of grace is for people who still need mercy.
Verse: Hebrews 4:16 — "Let us therefore come boldly unto the throne of grace."
Tags: prayer, trust
Minutes: 2

Mercy meets the person who **comes** before they feel ready.

### Ask for the Next Hour
Summary: Wisdom for this hour is given without a scolding.
Verse: James 1:5 — "If any of you lack wisdom, let him ask of God."
Tags: prayer, hope
Minutes: 1

Ask for the wisdom the next hour needs.
`;

test("app sections leave the devotion body and upsert on devo and position", () => {
  const devos = parseDevoMarkdown(card, { notionPageId: "page-8" });
  assert.equal(devos.length, 1);
  const devo = devos[0];
  assert.equal(devo.sections?.length, 2);
  assert.equal(devo.body_md.includes("App Sections"), false);
  assert.equal(devo.body_md.includes("###"), false);
  assert.equal(devo.body_md.includes("**"), false);
  const first = devo.sections![0];
  assert.equal(first.position, 1);
  assert.equal(first.verse_ref, "Hebrews 4:16");
  assert.equal(first.minutes, 2);
  assert.deepEqual(first.tags, ["prayer", "trust"]);
  const body = JSON.parse(first.body) as { v: number; blocks: Array<{ runs: Array<{ text: string; bold?: boolean }> }> };
  assert.equal(body.v, 1);
  assert.equal(body.blocks[0].runs[1].bold, true);
  assert.equal(body.blocks[0].runs[1].text, "comes");

  const rows = buildSectionUpsertRows("devo-1", devo.sections!);
  assert.equal(SECTION_UPSERT_ON_CONFLICT, "devo_id,position");
  assert.deepEqual(
    rows.map((row) => [row.devo_id, row.position, row.title]),
    [
      ["devo-1", 1, "Come Before You Feel Worthy"],
      ["devo-1", 2, "Ask for the Next Hour"],
    ],
  );
  const again = buildSectionUpsertRows("devo-1", devo.sections!);
  assert.deepEqual(again, rows);

  const links = buildSectionTagLinks(
    [
      { id: "s1", tags: first.tags },
      { id: "s2", tags: ["missing", "hope"] },
    ],
    new Map([
      ["prayer", "tag-prayer"],
      ["trust", "tag-trust"],
      ["hope", "tag-hope"],
    ]),
  );
  assert.deepEqual(links, [
    { section_id: "s1", tag_id: "tag-prayer" },
    { section_id: "s1", tag_id: "tag-trust" },
    { section_id: "s2", tag_id: "tag-hope" },
  ]);
});

test("a devotion with no app sections has an empty section list", () => {
  const markdown = `
**At a Glance**
The day can shake.

[Wednesday edition](https://microdevos.substack.com/p/sample)

## 1 · A Refuge That Does Not Move

The refuge does not relocate when the headlines do.
`;
  const devos = parseDevoMarkdown(markdown);
  assert.equal(devos.length, 1);
  assert.deepEqual(devos[0].sections, []);
  assert.equal(devos[0].body_md.includes("relocate"), true);
  assert.equal(buildSectionUpsertRows("devo-1", devos[0].sections ?? []).length, 0);
});
