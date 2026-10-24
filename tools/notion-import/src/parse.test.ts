import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import test from "node:test";
import { blocksToMarkdown } from "./blocks.js";
import { decide, parseDevoMarkdown, starsFromLabel } from "./parse.js";

const fixture = (name: string) =>
  readFileSync(
    path.resolve(import.meta.dirname, "../../../test/fixtures/notion", name),
    "utf8",
  );

test("parses the current card shape", () => {
  const markdown = fixture("newer.md");
  const decision = decide({
    status: "Archive",
    title: "Only God's Opinion of You Matters",
    markdown,
  });
  assert.equal(decision.shouldImport, true);
  const [devo] = parseDevoMarkdown(markdown, {
    status: "Archive",
    editionDate: "2026-10-14",
    stars: 3,
    notionPageId: "page-4",
  });
  assert.equal(devo.position, 4);
  assert.equal(devo.hook, "IDENTITY: Only God's opinion of you sticks.");
  assert.equal(devo.takeaway, "Today, write one sentence about who God says you are.");
  assert.equal(devo.verse_ref, "Matthew 5:14");
  assert.equal(devo.edition_url, "https://microdevos.substack.com/p/micro-devos-wednesday-october-14-2026");
  assert.equal(devo.scriptures.length, 2);
  assert.equal(devo.body_md.includes("Today, write"), false);
  assert.equal(devo.body_md.trim().startsWith("{"), true);
  const doc = JSON.parse(devo.body_md) as {
    v: number;
    blocks: { type: string; runs?: { text: string; bold?: boolean }[] }[];
  };
  assert.equal(doc.v, 1);
  assert.equal(
    doc.blocks.some(
      (block) =>
        block.type === "heading" &&
        (block.runs ?? []).map((run) => run.text).join("") === "Pressure",
    ),
    true,
  );
  assert.equal(
    doc.blocks.some((block) =>
      (block.runs ?? []).some((run) => run.bold && run.text.includes("Let God's view")),
    ),
    true,
  );
  assert.equal(devo.body_md.includes("###"), false);
  assert.equal(devo.body_md.includes("**"), false);
  assert.equal(devo.sections?.length ?? 0, 0);
  assert.equal(devo.teaser, "");
  assert.equal(devo.prayer, "");
});

test("parses the older sticky-lesson card", () => {
  const [devo] = parseDevoMarkdown(fixture("older.md"));
  assert.equal(devo.position, 6);
  assert.equal(devo.verse_ref, "Nehemiah 6:9");
  assert.match(devo.takeaway, /finish the work/);
  assert.equal(devo.scriptures[0].reference, "Nehemiah 6:9");
  assert.equal(devo.body_md.includes("Sticky lesson"), false);
});

test("parses a v6 card into three sections, a teaser, and a prayer", () => {
  const [devo] = parseDevoMarkdown(fixture("v6.md"));
  assert.equal(devo.hook, "HEART: A short glance line.");
  assert.equal(devo.takeaway, "The banner sentence stands on its own.");
  assert.equal(devo.teaser, "The teaser tells the story without repeating that sentence.");
  assert.equal(devo.prayer, "Offer one real help to a friend who has not asked.");
  assert.deepEqual(
    (devo.sections ?? []).map((section) => section.title),
    ["The Weight Nobody Named", "He Stepped Forward", "The Load Was Shared"],
  );
  assert.equal(devo.sections?.[0].verse_ref, "Gal 6:2");
  const stored = [devo.body_md, ...(devo.sections ?? []).map((section) => section.body)].join("\n");
  assert.equal(stored.includes("closing line"), false);
  assert.equal(stored.includes("Share card"), false);
  assert.equal(stored.includes("VERSE"), false);
  assert.equal(stored.includes("Today"), false);
});

test("skips ideas, prompts, and cards without an edition", () => {
  const body = fixture("newer.md");
  assert.match(decide({ status: "Ideas", title: "A real title", markdown: body }).shouldImport ? "" : "status", /status/);
  assert.equal(
    decide({ status: "Archive", title: "Prompt", markdown: fixture("skips.md") }).shouldImport,
    false,
  );
  assert.equal(starsFromLabel("★★★"), 3);
});

test("turns a verse callout block into the parser's markdown", () => {
  const markdown = blocksToMarkdown([
    {
      type: "heading_2",
      heading_2: { rich_text: [{ plain_text: "At a Glance · Monday" }] },
    },
    {
      type: "paragraph",
      paragraph: {
        rich_text: [{ plain_text: "A short hook.", annotations: { bold: true } }],
      },
    },
    {
      type: "heading_2",
      heading_2: { rich_text: [{ plain_text: "1 · A Title" }] },
    },
    {
      type: "paragraph",
      paragraph: { rich_text: [{ plain_text: "The reflection." }] },
    },
    {
      type: "callout",
      callout: {
        rich_text: [
          { plain_text: "VERSE · Psalm 23:1", annotations: { bold: true } },
          { plain_text: "\nThe LORD is my shepherd." },
        ],
      },
    },
    {
      type: "paragraph",
      paragraph: {
        rich_text: [
          { plain_text: "Edition: " },
          {
            plain_text: "Micro Devos",
            href: "https://microdevos.substack.com/p/sample",
            annotations: {},
          },
        ],
      },
    },
  ]);
  const [devo] = parseDevoMarkdown(markdown);
  assert.equal(devo.title, "A Title");
  assert.equal(devo.hook, "A short hook.");
  assert.equal(devo.verse_ref, "Psalm 23:1");
  assert.match(devo.verse_text, /shepherd/);
  assert.equal(devo.edition_url, "https://microdevos.substack.com/p/sample");
});
