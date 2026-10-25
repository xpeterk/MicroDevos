import assert from "node:assert/strict";
import test from "node:test";
import {
  plainSectionTitle,
  devoPrayerLine,
  relinkTagsToFilterTopics,
  buildV6SqlTransaction,
  type V6DayData,
} from "./loader.js";

test("plainSectionTitle removes role prefixes and numbers", () => {
  assert.equal(plainSectionTitle("1 · The Burden"), "The Burden");
  assert.equal(plainSectionTitle("Problem: The Noise"), "The Noise");
  assert.equal(plainSectionTitle("Action · Step Forward"), "Step Forward");
  assert.equal(plainSectionTitle("Result — Peace Settles"), "Peace Settles");
  assert.equal(plainSectionTitle("Already Clean Title"), "Already Clean Title");
});

test("devoPrayerLine formats prayer properly", () => {
  assert.equal(devoPrayerLine("Today: Help someone."), "🙏 Help someone.");
  assert.equal(devoPrayerLine("🙏 **Today:** Show kindness."), "🙏 Show kindness.");
  assert.equal(devoPrayerLine("Give us peace."), "🙏 Give us peace.");
  assert.equal(devoPrayerLine(""), "");
});

test("relinkTagsToFilterTopics maps tags to the 20 approved topics", () => {
  const topics = relinkTagsToFilterTopics(["action", "trouble", "gospel", "peace", "unknown-tag"]);
  // 'action' -> 'courage'
  // 'trouble' -> 'anxiety'
  // 'gospel' -> 'gospel-faith'
  // 'peace' -> 'peace'
  assert.ok(topics.includes("courage"));
  assert.ok(topics.includes("anxiety"));
  assert.ok(topics.includes("gospel-faith"));
  assert.ok(topics.includes("peace"));
  assert.equal(topics.includes("unknown-tag" as any), false);
});

test("buildV6SqlTransaction generates idempotent transaction with delete and insert", () => {
  const data: V6DayData = {
    edition_date: "2026-10-19",
    devos: [
      {
        position: 1,
        title: "Test Title",
        teaser: "Test Teaser",
        prayer: "🙏 Lord guide us.",
        sections: [
          {
            position: 1,
            title: "Problem · Hard Times",
            summary: "Things get tough.",
            verse_ref: "Ps 23:1",
            verse_text: "The Lord is my shepherd.",
            body: "Body 1",
            tags: ["courage", "action"],
            image_url: "https://example.com/banner1.jpg",
            image_alt: "Mountain path",
          },
          {
            position: 2,
            title: "Action · Stand Firm",
            summary: "Keep moving.",
            body: "Body 2",
            tags: ["hope"],
            image_url: null,
            image_alt: null,
          },
          {
            position: 3,
            title: "Result · Light Comes",
            summary: "Peace follows.",
            body: "Body 3",
            tags: ["peace"],
            image_url: "https://example.com/banner3.jpg",
            image_alt: "Sunrise",
          },
        ],
      },
    ],
  };

  const sql = buildV6SqlTransaction(data);
  assert.ok(sql.startsWith("BEGIN;"));
  assert.ok(sql.endsWith("COMMIT;"));
  assert.ok(sql.includes("UPDATE public.devos"));
  assert.ok(sql.includes("DELETE FROM public.devo_sections"));
  assert.ok(sql.includes("INSERT INTO public.devo_sections"));
  assert.ok(sql.includes("INSERT INTO public.section_tags"));
  assert.ok(sql.includes("INSERT INTO public.devo_tags"));
  assert.ok(sql.includes("https://example.com/banner1.jpg"));
});
