import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";

export const APPROVED_FILTER_TOPICS = [
  "courage",
  "anxiety",
  "fear",
  "hope",
  "peace",
  "gratitude",
  "grief",
  "trust",
  "prayer",
  "rest",
  "scripture",
  "waiting",
  "perseverance",
  "identity",
  "work",
  "family",
  "gospel-faith",
  "love-kindness",
  "church-community",
  "grace-holiness",
] as const;

export type FilterTopic = typeof APPROVED_FILTER_TOPICS[number];

export const CHILD_TO_PARENT_TAG_MAP: Record<string, FilterTopic> = {
  action: "courage",
  belonging: "identity",
  calling: "work",
  character: "identity",
  church: "church-community",
  comfort: "peace",
  communion: "church-community",
  community: "church-community",
  discipline: "perseverance",
  encouragement: "hope",
  endurance: "perseverance",
  evangelism: "gospel-faith",
  faith: "trust",
  faithfulness: "trust",
  foundation: "trust",
  freedom: "peace",
  friendship: "church-community",
  fruitfulness: "work",
  gospel: "gospel-faith",
  grace: "grace-holiness",
  healing: "hope",
  history: "scripture",
  holiness: "grace-holiness",
  honesty: "courage",
  honor: "identity",
  humility: "grace-holiness",
  influence: "work",
  invitation: "gospel-faith",
  jesus: "gospel-faith",
  justice: "love-kindness",
  kindness: "love-kindness",
  leadership: "work",
  legacy: "family",
  love: "love-kindness",
  power: "courage",
  priorities: "work",
  protection: "trust",
  providence: "trust",
  refuge: "peace",
  relationships: "family",
  salvation: "gospel-faith",
  security: "trust",
  servanthood: "grace-holiness",
  service: "work",
  "small-things": "work",
  strength: "courage",
  surrender: "trust",
  trouble: "anxiety",
  value: "identity",
  vulnerability: "fear",
  weakness: "fear",
  welcome: "church-community",
  worship: "church-community",
  worth: "identity",
};

export function plainSectionTitle(title: string): string {
  const original = title.trim();
  let text = original.replace(/^\d+\s*[.·•)\-–—]\s*/, "");
  text = text.replace(/^(?:problem|action|result)\s*[·:•\-–—]\s*/i, "");
  const plain = text.trim();
  return plain.length === 0 ? original : plain;
}

export function devoPrayerLine(prayer: string): string {
  let text = prayer.trim();
  if (!text) return "";
  text = text.replace(/^🙏\s*/, "");
  text = text.replace(/\*\*/g, "");
  text = text.replace(/^Today:\s*/i, "");
  text = text.trim();
  if (!text) return "";
  return `🙏 ${text}`;
}

export function relinkTagsToFilterTopics(tags: string[]): FilterTopic[] {
  const filterSet = new Set<string>(APPROVED_FILTER_TOPICS);
  const result = new Set<FilterTopic>();

  for (const raw of tags) {
    const slug = raw.trim().toLowerCase();
    if (filterSet.has(slug)) {
      result.add(slug as FilterTopic);
    } else if (CHILD_TO_PARENT_TAG_MAP[slug]) {
      result.add(CHILD_TO_PARENT_TAG_MAP[slug]);
    }
  }

  return [...result];
}

export type V6SectionInput = {
  position: number;
  title: string;
  summary: string;
  minutes?: number;
  verse?: string;
  verse_ref?: string;
  verse_text?: string;
  body?: string;
  tags?: string[];
  image_url?: string | null;
  image_alt?: string | null;
};

export type V6DevoInput = {
  position: number;
  title?: string;
  teaser: string;
  prayer: string;
  sections: V6SectionInput[];
};

export type V6DayData = {
  edition_date: string;
  devos: V6DevoInput[];
};

export function readDayContent(baseDir: string, date: string): V6DayData | null {
  const dayDir = path.join(baseDir, date);
  if (!existsSync(dayDir)) {
    return null;
  }

  const sectionsPath = path.join(dayDir, "sections_v6.json");
  if (!existsSync(sectionsPath)) {
    return null;
  }

  const sectionsJson = JSON.parse(readFileSync(sectionsPath, "utf8"));
  let imagesJson: Record<string, any> = {};
  const imagesPath = path.join(dayDir, "images_v6.json");
  if (existsSync(imagesPath)) {
    imagesJson = JSON.parse(readFileSync(imagesPath, "utf8"));
  }

  // Load auxiliary titles, teasers, prayers if present
  let titlesList: string[] = [];
  let teasersList: string[] = [];
  let prayersList: string[] = [];

  const readLines = (file: string) =>
    existsSync(file)
      ? readFileSync(file, "utf8")
          .split(/\r?\n/)
          .map((l) => l.trim())
          .filter(Boolean)
      : [];

  const readJsonOrLines = (name: string) => {
    const jsonFile = path.join(dayDir, `${name}.json`);
    if (existsSync(jsonFile)) {
      const data = JSON.parse(readFileSync(jsonFile, "utf8"));
      return Array.isArray(data) ? data : [];
    }
    return readLines(path.join(dayDir, `${name}.txt`));
  };

  titlesList = readJsonOrLines("titles");
  teasersList = readJsonOrLines("teasers");
  prayersList = readJsonOrLines("prayers");

  const devos: V6DevoInput[] = [];

  // Parse sections structure (can be array of devos or flat list of sections)
  if (Array.isArray(sectionsJson)) {
    // If it's 8 devos with sections inside
    if (sectionsJson.length > 0 && "sections" in sectionsJson[0]) {
      for (let i = 0; i < sectionsJson.length; i++) {
        const item = sectionsJson[i];
        const pos = item.position ?? i + 1;
        const title = item.title ?? titlesList[pos - 1] ?? "";
        const teaser = item.teaser ?? teasersList[pos - 1] ?? "";
        const prayer = devoPrayerLine(item.prayer ?? prayersList[pos - 1] ?? "");
        const rawSections = item.sections || [];

        const sections: V6SectionInput[] = rawSections.map((s: any, idx: number) => {
          const sPos = s.position ?? idx + 1;
          const imageKey = `${pos}-${sPos}`;
          const img =
            (Array.isArray(imagesJson)
              ? imagesJson.find(
                  (im: any) =>
                    (im.devo_position === pos || im.position === pos) &&
                    (im.section_position === sPos || im.sub_position === sPos),
                )
              : imagesJson[imageKey] || imagesJson[`pos_${pos}_${sPos}`]) ?? {};

          return {
            position: sPos,
            title: plainSectionTitle(s.title || ""),
            summary: (s.summary || "").trim(),
            minutes: s.minutes ?? 1,
            verse_ref: (s.verse_ref || s.verse || "").trim(),
            verse_text: (s.verse_text || "").trim(),
            body: typeof s.body === "object" ? JSON.stringify(s.body) : String(s.body || ""),
            tags: s.tags || [],
            image_url: s.image_url ?? img.image_url ?? img.url ?? null,
            image_alt: s.image_alt ?? img.image_alt ?? img.alt ?? null,
          };
        });

        devos.push({
          position: pos,
          title,
          teaser,
          prayer,
          sections,
        });
      }
    } else {
      // Flat list of sections (24 sections)
      for (let pos = 1; pos <= 8; pos++) {
        const title = titlesList[pos - 1] ?? "";
        const teaser = teasersList[pos - 1] ?? "";
        const prayer = devoPrayerLine(prayersList[pos - 1] ?? "");
        const devoSections = sectionsJson.filter(
          (s: any) => s.devo_position === pos || s.devoPosition === pos,
        );

        const sections: V6SectionInput[] = devoSections.map((s: any, idx: number) => {
          const sPos = s.position ?? idx + 1;
          const imageKey = `${pos}-${sPos}`;
          const img =
            (Array.isArray(imagesJson)
              ? imagesJson.find(
                  (im: any) =>
                    (im.devo_position === pos || im.position === pos) &&
                    (im.section_position === sPos || im.sub_position === sPos),
                )
              : imagesJson[imageKey]) ?? {};

          return {
            position: sPos,
            title: plainSectionTitle(s.title || ""),
            summary: (s.summary || "").trim(),
            minutes: s.minutes ?? 1,
            verse_ref: (s.verse_ref || s.verse || "").trim(),
            verse_text: (s.verse_text || "").trim(),
            body: typeof s.body === "object" ? JSON.stringify(s.body) : String(s.body || ""),
            tags: s.tags || [],
            image_url: s.image_url ?? img.image_url ?? null,
            image_alt: s.image_alt ?? img.image_alt ?? null,
          };
        });

        devos.push({
          position: pos,
          title,
          teaser,
          prayer,
          sections,
        });
      }
    }
  }

  return {
    edition_date: date,
    devos,
  };
}

export function buildV6SqlTransaction(data: V6DayData): string {
  const statements: string[] = ["BEGIN;"];
  const date = data.edition_date;

  for (const devo of data.devos) {
    const escapedTeaser = devo.teaser.replace(/'/g, "''");
    const escapedPrayer = devo.prayer.replace(/'/g, "''");

    statements.push(`
      UPDATE public.devos
      SET teaser = '${escapedTeaser}',
          prayer = '${escapedPrayer}'
      WHERE edition_date = '${date}' AND position = ${devo.position};
    `);

    // Remove existing sections for this devo
    statements.push(`
      DELETE FROM public.devo_sections
      WHERE devo_id IN (
        SELECT id FROM public.devos WHERE edition_date = '${date}' AND position = ${devo.position}
      );
    `);

    // Insert exactly 3 sections
    for (const section of devo.sections) {
      const escapedTitle = section.title.replace(/'/g, "''");
      const escapedSummary = section.summary.replace(/'/g, "''");
      const escapedRef = (section.verse_ref || "").replace(/'/g, "''");
      const escapedVerse = (section.verse_text || "").replace(/'/g, "''");
      const escapedBody = (section.body || "").replace(/'/g, "''");
      const imageUrlVal = section.image_url ? `'${section.image_url.replace(/'/g, "''")}'` : "NULL";
      const imageAltVal = section.image_alt ? `'${section.image_alt.replace(/'/g, "''")}'` : "NULL";
      const minutes = section.minutes ?? 1;

      const filterTopics = relinkTagsToFilterTopics(section.tags || []);

      statements.push(`
        WITH target_devo AS (
          SELECT id FROM public.devos WHERE edition_date = '${date}' AND position = ${devo.position} LIMIT 1
        ),
        inserted_sec AS (
          INSERT INTO public.devo_sections (
            devo_id, position, title, summary, minutes, verse_ref, verse_text, body, image_url, image_alt
          )
          SELECT
            target_devo.id,
            ${section.position},
            '${escapedTitle}',
            '${escapedSummary}',
            ${minutes},
            '${escapedRef}',
            '${escapedVerse}',
            '${escapedBody}',
            ${imageUrlVal},
            ${imageAltVal}
          FROM target_devo
          RETURNING id, devo_id
        )
        INSERT INTO public.section_tags (section_id, tag_id)
        SELECT inserted_sec.id, public.tags.id
        FROM inserted_sec, public.tags
        WHERE public.tags.slug IN (${
          filterTopics.length > 0
            ? filterTopics.map((t) => `'${t}'`).join(", ")
            : "''"
        })
        ON CONFLICT (section_id, tag_id) DO NOTHING;
      `);
    }

    // Relink devo_tags to the union of section filter topics
    const allDevoFilterTopics = Array.from(
      new Set(devo.sections.flatMap((s) => relinkTagsToFilterTopics(s.tags || []))),
    );

    if (allDevoFilterTopics.length > 0) {
      statements.push(`
        WITH target_devo AS (
          SELECT id FROM public.devos WHERE edition_date = '${date}' AND position = ${devo.position} LIMIT 1
        )
        INSERT INTO public.devo_tags (devo_id, tag_id)
        SELECT target_devo.id, public.tags.id
        FROM target_devo, public.tags
        WHERE public.tags.slug IN (${allDevoFilterTopics.map((t) => `'${t}'`).join(", ")})
        ON CONFLICT (devo_id, tag_id) DO NOTHING;
      `);
    }
  }

  statements.push("COMMIT;");
  return statements.join("\n");
}
