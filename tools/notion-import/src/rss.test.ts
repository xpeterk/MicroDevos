import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { loadFixtureCards } from "./fixture.js";
import { readBannerAlt, readBannerUrl } from "./notion.js";
import { planImport, toUpsertRows } from "./pipeline.js";
import {
  bannerWritePayload,
  formatBannerReport,
  logBannerWarnings,
  matchBanners,
  parseRssFeed,
  type BannerUpdate,
} from "./rss.js";

const feedPath = new URL("../fixtures/substack-feed.xml", import.meta.url);
const cardsPath = new URL("../fixtures/sample-cards.json", import.meta.url);
const feedXml = readFileSync(feedPath, "utf8");

function friday() {
  const edition = parseRssFeed(feedXml).find((item) => item.editionDate === "2026-10-16");
  assert.ok(edition);
  return edition;
}

test("parses the saved feed fixture into per-devo banners", () => {
  const first = parseRssFeed(feedXml);
  const second = parseRssFeed(feedXml);
  assert.deepEqual(second, first);

  const edition = first.find((item) => item.editionDate === "2026-10-16");
  assert.ok(edition);
  assert.equal(edition.title, "Micro Devos · Friday, October 16, 2026");
  assert.equal(
    edition.link,
    "https://microdevotionals.substack.com/p/micro-devos-friday-october-16-2026",
  );
  assert.equal(edition.banners.length, 8);
  assert.deepEqual(
    edition.banners.map((banner) => banner.position),
    [1, 2, 3, 4, 5, 6, 7, 8],
  );
  assert.equal(edition.warnings.length, 0);

  const banner = edition.banners[0];
  assert.equal(banner.title, "The Week the Leaders Called Home");
  assert.match(banner.imageUrl, /^https:\/\/substackcdn\.com\/image\/fetch\//);
  assert.match(banner.imageUrl, /7615f705-2bcc-479c-aef4-0188288a5c42_1200x315\.png/);
  assert.match(banner.imageAlt, /^The Week the Leaders Called Home\. FORGIVENESS/);
  assert.equal(banner.imageAlt.startsWith("Devotion"), false);
  assert.equal(edition.banners[2].title, "The Button He Had Never Pressed");
  assert.match(edition.banners[2].imageAlt, /God\u2019s answer/);
  assert.equal(
    edition.banners.some((item) => item.imageUrl.includes("enclosure_1200x630")),
    false,
  );
  assert.equal(
    edition.banners.some((item) => item.imageAlt.includes("Cast your bread")),
    false,
  );
});

test("uses the devotion label rather than image order, and skips non-CDN images", () => {
  const edition = parseRssFeed(feedXml).find((item) => item.editionDate === "2026-10-01");
  assert.ok(edition);
  assert.deepEqual(
    edition.banners.map((banner) => [banner.position, banner.title]),
    [
      [1, "First by label"],
      [2, "Second by label"],
    ],
  );
  assert.match(edition.banners[0].imageUrl, /first_1200x315/);
  assert.ok(edition.warnings.some((warning) => warning.includes("non-CDN")));
  assert.ok(edition.warnings.some((warning) => warning.includes("no banner for position 3")));
});

test("leaves unmatched positions null and logs a warning", () => {
  const edition = parseRssFeed(feedXml).find((item) => item.editionDate === "2026-10-05");
  assert.ok(edition);
  assert.equal(edition.banners.length, 2);
  const logged: string[] = [];
  const plan = matchBanners(parseRssFeed(feedXml), []);
  const again = matchBanners(parseRssFeed(feedXml), []);
  assert.deepEqual(again, plan);
  logBannerWarnings(plan.warnings, (message) => logged.push(message));

  const missing = plan.updates.find(
    (update) => update.editionDate === "2026-10-05" && update.position === 3,
  );
  assert.ok(missing);
  assert.equal(missing.imageUrl, null);
  assert.equal(missing.imageAlt, null);
  assert.equal(missing.matchedBy, null);
  assert.ok(logged.some((message) => message.startsWith("warning:") && message.includes("position 3")));
  assert.ok(plan.warnings.some((warning) => warning.includes("duplicate RSS post for 2026-10-05")));
  assert.equal(
    plan.updates.filter((update) => update.editionDate === "2026-10-05" && update.imageUrl).length,
    2,
  );
  assert.match(plan.updates.find((update) => update.editionDate === "2026-10-05" && update.position === 1)!.imageAlt!, /Only the First/);
});

test("an undated post does not become an edition", () => {
  const edition = parseRssFeed(feedXml).find((item) => item.title === "Office notes");
  assert.ok(edition);
  assert.equal(edition.editionDate, null);
  assert.ok(edition.warnings.some((warning) => warning.includes("no edition date")));
  const plan = matchBanners([edition], []);
  assert.equal(plan.updates.length, 0);
});

test("title match wins over banner order, and a miss stays null", () => {
  const editions = parseRssFeed(feedXml);
  const plan = matchBanners(editions, [
    {
      editionDate: "2026-10-16",
      position: 1,
      title: "A Tree Shaker and an Applesauce Maker",
    },
    {
      editionDate: "2026-10-16",
      position: 2,
      title: "The Week the Leaders Called Home",
    },
    {
      editionDate: "2026-10-05",
      position: 4,
      title: "Not in this post",
    },
  ]);

  const tree = plan.updates.find((update) => update.position === 1);
  const week = plan.updates.find((update) => update.position === 2);
  const miss = plan.updates.find((update) => update.position === 4);
  assert.ok(tree && week && miss);
  assert.equal(tree.matchedBy, "title");
  assert.match(tree.imageUrl!, /\$s_!UKcj!/);
  assert.match(tree.imageAlt!, /A Tree Shaker and an Applesauce Maker/);
  assert.equal(week.matchedBy, "title");
  assert.match(week.imageUrl!, /7615f705-2bcc-479c-aef4-0188288a5c42/);
  assert.equal(miss.imageUrl, null);
  assert.equal(miss.imageAlt, null);
  assert.ok(plan.warnings.some((warning) => warning.includes("Not in this post") && warning.includes("left null")));
});

test("banner writes cannot carry notion text, and notion rows do not carry banners", async () => {
  const update: BannerUpdate = {
    editionDate: "2026-10-16",
    position: 3,
    imageUrl: friday().banners[2].imageUrl,
    imageAlt: friday().banners[2].imageAlt,
    matchedBy: "position",
  };
  const payload = bannerWritePayload(update);
  assert.deepEqual(Object.keys(payload).sort(), ["image_alt", "image_url"]);
  assert.equal(payload.image_url, update.imageUrl);
  assert.equal(payload.image_alt, update.imageAlt);

  const cards = await loadFixtureCards(cardsPath);
  const plan = await planImport(cards);
  const devo = plan.imported[0];
  assert.equal(devo.title, "A Refuge That Does Not Move");
  const row = toUpsertRows(plan.imported)[0];
  assert.equal(row.title, devo.title);
  assert.equal(row.hook, devo.hook);
  assert.equal(row.body_md, devo.body_md);
  assert.equal(row.takeaway, devo.takeaway);
  assert.equal("image_url" in row, false);
  assert.equal("image_alt" in row, false);

  const matched = matchBanners(parseRssFeed(feedXml), [
    { editionDate: devo.edition_date!, position: devo.position, title: devo.title },
  ]);
  const banner = matched.updates.find((item) => item.position === devo.position);
  assert.ok(banner);
  assert.equal(banner.matchedBy, "position");
  assert.match(banner.imageAlt!, /The Button He Had Never Pressed/);
  assert.equal("title" in banner, false);
  assert.equal("hook" in banner, false);
});

test("a notion banner wins over the rss match", async () => {
  const filesUrl = readBannerUrl({
    Banner: {
      type: "files",
      files: [
        {
          name: "banner.png",
          type: "file",
          file: { url: "https://cdn.example.com/hosted-banner.png" },
        },
      ],
    },
  });
  assert.equal(filesUrl, "https://cdn.example.com/hosted-banner.png");
  const externalUrl = readBannerUrl({
    Banner: {
      type: "files",
      files: [
        { type: "external", external: { url: "https://cdn.example.com/external-banner.png" } },
      ],
    },
  });
  assert.equal(externalUrl, "https://cdn.example.com/external-banner.png");

  const cards = await loadFixtureCards(cardsPath);
  const card = {
    ...cards[0],
    properties: {
      ...cards[0].properties,
      Banner: { type: "url", url: "https://example.com/notion-banner.png" },
      "Banner Alt": {
        type: "rich_text",
        rich_text: [{ plain_text: "A still morning" }],
      },
    },
  };
  const imported = await planImport([card]);
  const devo = imported.imported[0];
  assert.equal(devo.notion_banner_url, "https://example.com/notion-banner.png");
  assert.equal(devo.notion_banner_alt, "A still morning");
  assert.equal(devo.title, "A Refuge That Does Not Move");
  assert.equal(devo.hook.includes("refuge"), true);
  const row = toUpsertRows(imported.imported)[0];
  assert.equal("image_url" in row, false);
  assert.equal("image_alt" in row, false);
  assert.equal("notion_banner_url" in row, false);

  const plan = matchBanners(parseRssFeed(feedXml), [
    {
      editionDate: "2026-10-16",
      position: 1,
      title: "The Week the Leaders Called Home",
      notionBannerUrl: devo.notion_banner_url,
      notionBannerAlt: devo.notion_banner_alt,
    },
  ]);
  assert.equal(plan.updates.length, 1);
  assert.equal(plan.updates[0].imageUrl, "https://example.com/notion-banner.png");
  assert.equal(plan.updates[0].imageAlt, "A still morning");
  assert.equal(plan.updates[0].matchedBy, "notion");
  assert.equal(plan.updates[0].imageUrl.includes("substackcdn.com"), false);
  assert.equal(
    plan.warnings.some((warning) => warning.includes("left null")),
    false,
  );

  const offFeed = matchBanners(parseRssFeed(feedXml), [
    {
      editionDate: "2026-01-02",
      position: 3,
      title: devo.title,
      notionBannerUrl: devo.notion_banner_url,
      notionBannerAlt: devo.notion_banner_alt,
    },
  ]);
  assert.equal(offFeed.updates[0].imageUrl, "https://example.com/notion-banner.png");
  assert.equal(offFeed.updates[0].imageAlt, "A still morning");
  assert.equal(offFeed.updates[0].matchedBy, "notion");
});

test("a missing notion banner falls back to the rss match", () => {
  assert.equal(readBannerUrl({}), null);
  assert.equal(readBannerAlt({}), null);
  assert.equal(readBannerUrl({ Status: { select: { name: "Archive" } } }), null);
  assert.equal(readBannerAlt({ Idea: { title: [{ plain_text: "Only a title" }] } }), null);
  assert.equal(readBannerUrl({ Banner: { type: "url", url: null } }), null);
  assert.equal(readBannerUrl({ Banner: { type: "url", url: "  " } }), null);
  assert.equal(readBannerUrl({ Banner: { type: "files", files: [] } }), null);
  assert.equal(readBannerAlt({ "Banner Alt": { type: "rich_text", rich_text: [] } }), null);

  const plan = matchBanners(parseRssFeed(feedXml), [
    {
      editionDate: "2026-10-16",
      position: 1,
      title: "Not the rss title",
      notionBannerUrl: readBannerUrl({}),
      notionBannerAlt: readBannerAlt({}),
    },
  ]);
  const update = plan.updates[0];
  assert.equal(update.matchedBy, "position");
  assert.match(update.imageUrl!, /7615f705-2bcc-479c-aef4-0188288a5c42/);
  assert.match(update.imageAlt!, /^The Week the Leaders Called Home\./);
  assert.equal(update.imageAlt!.startsWith("Devotion"), false);
  assert.equal(plan.warnings.some((warning) => warning.includes("left null")), false);
});

test("no notion banner and no rss match leaves the image null", () => {
  const logged: string[] = [];
  const plan = matchBanners(parseRssFeed(feedXml), [
    {
      editionDate: "2026-10-05",
      position: 4,
      title: "Not in this post",
      notionBannerUrl: null,
      notionBannerAlt: null,
    },
  ]);
  logBannerWarnings(plan.warnings, (message) => logged.push(message));
  assert.equal(plan.updates.length, 1);
  assert.equal(plan.updates[0].imageUrl, null);
  assert.equal(plan.updates[0].imageAlt, null);
  assert.equal(plan.updates[0].matchedBy, null);
  assert.ok(
    logged.some(
      (message) => message.startsWith("warning:") && message.includes("image_url left null"),
    ),
  );
});

test("a matching Banner Alt prefix is stripped, and a mismatch keeps the heading", async () => {
  const cards = await loadFixtureCards(cardsPath);
  const base = cards[0];
  const alt = {
    type: "rich_text",
    rich_text: [{ plain_text: "Devotion 3: A still morning. HOPE · 1-min read. Rest here." }],
  };
  const matching = await planImport([
    {
      ...base,
      properties: {
        ...base.properties,
        Banner: { type: "url", url: "https://example.com/notion-banner.png" },
        "Banner Alt": alt,
      },
    },
  ]);
  assert.equal(matching.bannerWarnings.length, 0);
  assert.equal(matching.imported[0].position, 3);
  assert.equal(matching.imported[0].title, "A Refuge That Does Not Move");
  assert.equal(matching.imported[0].notion_banner_alt, "A still morning. HOPE · 1-min read. Rest here.");

  const mismatched = await planImport([
    {
      ...base,
      properties: {
        ...base.properties,
        Banner: { type: "url", url: "https://example.com/notion-banner.png" },
        "Banner Alt": {
          type: "rich_text",
          rich_text: [{ plain_text: "Devotion 1: A still morning. HOPE · 1-min read. Rest here." }],
        },
      },
    },
  ]);
  const devo = mismatched.imported[0];
  assert.equal(devo.position, 3);
  assert.equal(devo.notion_banner_url, "https://example.com/notion-banner.png");
  assert.equal(devo.notion_banner_alt, "A still morning. HOPE · 1-min read. Rest here.");
  assert.equal(mismatched.bannerWarnings.length, 1);
  assert.match(mismatched.bannerWarnings[0], /banner alt says Devotion 1 but the heading is 3/);
  assert.match(mismatched.bannerWarnings[0], /using the heading/);

  const plan = matchBanners(parseRssFeed(feedXml), [
    {
      editionDate: "2026-10-16",
      position: devo.position,
      title: devo.title,
      notionBannerUrl: devo.notion_banner_url,
      notionBannerAlt: devo.notion_banner_alt,
    },
  ]);
  assert.equal(plan.updates.length, 1);
  assert.equal(plan.updates[0].position, 3);
  assert.equal(plan.updates[0].imageUrl, "https://example.com/notion-banner.png");
  assert.equal(plan.updates[0].imageAlt, "A still morning. HOPE · 1-min read. Rest here.");
  assert.equal(plan.updates[0].matchedBy, "notion");
});

test("a shared header is not a devotion banner", () => {
  const xml = `<?xml version="1.0"?>
<rss xmlns:content="http://purl.org/rss/1.0/modules/content/"><channel>
<item>
<title>Micro Devos · Monday, September 28, 2026</title>
<link>https://microdevotionals.substack.com/p/sep-28</link>
<pubDate>Mon, 28 Sep 2026 12:00:00 +0000</pubDate>
<content:encoded><![CDATA[
<img src="https://substackcdn.com/image/fetch/$s_!cover!/https%3A%2F%2Fsubstack-post-media.s3.amazonaws.com%2Fpublic%2Fimages%2Fcover_1200x630.png" width="1200" height="630" alt="">
<img src="https://substackcdn.com/image/fetch/$s_!hdr!/https%3A%2F%2Fsubstack-post-media.s3.amazonaws.com%2Fpublic%2Fimages%2Fshared_header.png" width="1200" height="400" alt="This week's edition">
]]></content:encoded>
</item>
</channel></rss>`;
  const [edition] = parseRssFeed(xml);
  assert.equal(edition.editionDate, "2026-09-28");
  assert.equal(edition.banners.length, 0);
  assert.ok(edition.warnings.some((warning) => warning === "skipped a shared header; it is not a per-devo banner"));
  const plan = matchBanners([edition], [
    {
      editionDate: "2026-09-28",
      position: 1,
      title: "A Monday devotion",
      notionBannerUrl: null,
      notionBannerAlt: null,
    },
  ]);
  assert.equal(plan.updates.length, 1);
  assert.equal(plan.updates[0].position, 1);
  assert.equal(plan.updates[0].imageUrl, null);
  assert.equal(plan.updates[0].imageAlt, null);
  assert.equal(plan.updates[0].matchedBy, null);
  assert.equal(
    plan.updates.some((update) => (update.imageUrl ?? "").includes("shared_header")),
    false,
  );
});

test("the dry-run report counts matches for each dated post", () => {
  const report = formatBannerReport("fixtures/substack-feed.xml", parseRssFeed(feedXml));
  assert.match(report, /2026-10-16 {2}matched 8\/8 {2}Micro Devos · Friday, October 16, 2026/);
  assert.match(report, /2026-10-01 {2}matched 2\/8/);
  assert.match(report, /2026-10-05 {2}matched 2\/8/);
  assert.match(report, /undated {2}matched 0\/8 {2}Office notes/);
  assert.match(report, /4 editions, 13 banners matched, 27 left null/);
});
