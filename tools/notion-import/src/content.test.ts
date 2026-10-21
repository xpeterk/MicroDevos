import assert from "node:assert/strict";
import test from "node:test";
import { blocksToMarkdown, richTextToMarkdown } from "./blocks.js";
import { encodeContent, parseInlines } from "./content.js";

test("notion annotations become markers the document parser keeps", () => {
  const markdown = richTextToMarkdown([
    { plain_text: "strong", annotations: { bold: true } },
    { plain_text: " " },
    { plain_text: "soft", annotations: { italic: true } },
    { plain_text: " " },
    { plain_text: "line", annotations: { underline: true } },
    { plain_text: " " },
    { plain_text: "gone", annotations: { strikethrough: true } },
    { plain_text: " " },
    { plain_text: "code", annotations: { code: true } },
    { plain_text: " ", href: null },
    { plain_text: "Psalm 46", href: "https://example.com/psalm" },
  ]);
  assert.match(markdown, /\*\*strong\*\*/);
  assert.match(markdown, /\*soft\*/);
  assert.match(markdown, /\+\+line\+\+/);
  assert.match(markdown, /~~gone~~/);
  assert.match(markdown, /`code`/);
  assert.match(markdown, /\[Psalm 46\]\(https:\/\/example.com\/psalm\)/);

  const runs = parseInlines(markdown);
  assert.equal(runs.find((run) => run.text === "strong")?.bold, true);
  assert.equal(runs.find((run) => run.text === "soft")?.italic, true);
  assert.equal(runs.find((run) => run.text === "line")?.underline, true);
  assert.equal(runs.find((run) => run.text === "gone")?.strike, true);
  assert.equal(runs.find((run) => run.text === "code")?.code, true);
  assert.equal(runs.find((run) => run.text === "Psalm 46")?.link, "https://example.com/psalm");
  assert.equal(markdown.includes("***"), false);
});

test("blocks become structured json without markdown markers", () => {
  const markdown = blocksToMarkdown([
    { type: "heading_2", heading_2: { rich_text: [{ plain_text: "Known on every road" }] } },
    {
      type: "paragraph",
      paragraph: {
        rich_text: [
          { plain_text: "God is " },
          { plain_text: "near", annotations: { bold: true } },
          { plain_text: " and " },
          { plain_text: "present", annotations: { italic: true, underline: true } },
        ],
      },
    },
    { type: "bulleted_list_item", bulleted_list_item: { rich_text: [{ plain_text: "Sit still" }] } },
    { type: "numbered_list_item", numbered_list_item: { rich_text: [{ plain_text: "Speak" }] } },
    { type: "quote", quote: { rich_text: [{ plain_text: "Never out of sight." }] } },
    { type: "callout", callout: { rich_text: [{ plain_text: "God knows the way home." }] } },
    { type: "divider" },
  ]);
  const doc = JSON.parse(encodeContent(markdown)) as {
    v: number;
    blocks: { type: string; runs?: { text: string }[] }[];
  };
  assert.deepEqual(
    doc.blocks.map((block) => block.type),
    ["heading", "paragraph", "bullet", "number", "quote", "callout", "divider"],
  );
  const plain = JSON.stringify(doc);
  assert.equal(plain.includes("###"), false);
  assert.equal(plain.includes("**"), false);
  assert.equal(plain.includes(":::"), false);
  assert.equal(plain.includes("near"), true);
  assert.equal(plain.includes("God knows the way home."), true);
});
