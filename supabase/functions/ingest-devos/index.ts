import { createClient } from "jsr:@supabase/supabase-js@2";

type Scripture = { reference?: string; text?: string };

type IngestDevo = {
  title?: string;
  hook?: string;
  body_md?: string;
  takeaway?: string;
  verse_text?: string;
  verse_ref?: string;
  scriptures?: Scripture[];
  source_url?: string | null;
  position?: number;
  stars?: number | null;
  status?: string;
  notion_page_id?: string | null;
  tags?: string[];
};

type IngestBody = {
  edition_date?: string;
  edition_url?: string | null;
  devos?: IngestDevo[];
};

const DATE = /^\d{4}-\d{2}-\d{2}$/;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function secretsMatch(given: string, expected: string): boolean {
  if (!expected || given.length !== expected.length) return false;
  let mismatch = 0;
  for (let i = 0; i < given.length; i++) {
    mismatch |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return mismatch === 0;
}

function validate(body: IngestBody): string | null {
  if (!body.edition_date || !DATE.test(body.edition_date)) {
    return "edition_date must be YYYY-MM-DD";
  }
  if (!Array.isArray(body.devos) || body.devos.length < 1 || body.devos.length > 8) {
    return "devos must contain 1 to 8 items";
  }
  const positions = new Set<number>();
  for (const devo of body.devos) {
    if (!devo.title?.trim()) return "each devo needs a title";
    if (!devo.hook?.trim()) return "each devo needs a hook";
    if (!devo.body_md?.trim()) return "each devo needs body_md";
    if (!devo.takeaway?.trim()) return "each devo needs a takeaway";
    if (!devo.verse_ref?.trim() || !devo.verse_text?.trim()) {
      return "each devo needs verse_ref and verse_text";
    }
    if (
      typeof devo.position !== "number" ||
      devo.position < 1 ||
      devo.position > 8 ||
      positions.has(devo.position)
    ) {
      return "positions must be unique integers from 1 to 8";
    }
    positions.add(devo.position);
    if (devo.stars != null && (devo.stars < 1 || devo.stars > 3)) {
      return "stars must be 1, 2, 3, or omitted";
    }
  }
  return null;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const expected = Deno.env.get("INGEST_SHARED_SECRET") ?? "";
  const given = req.headers.get("x-ingest-secret") ?? "";
  if (!secretsMatch(given, expected)) return json({ error: "Unauthorized" }, 401);

  let body: IngestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const problem = validate(body);
  if (problem) return json({ error: problem }, 400);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceKey) {
    return json({ error: "Supabase service credentials are not configured" }, 500);
  }

  const supabase = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const rows = body.devos!.map((devo) => ({
    title: devo.title!.trim(),
    hook: devo.hook!.trim(),
    body_md: devo.body_md!.trim(),
    takeaway: devo.takeaway!.trim(),
    verse_text: devo.verse_text!.trim(),
    verse_ref: devo.verse_ref!.trim(),
    scriptures: (devo.scriptures ?? [])
      .filter((quote) => quote.reference && quote.text)
      .map((quote) => ({ reference: quote.reference, text: quote.text })),
    source_url: devo.source_url ?? null,
    edition_date: body.edition_date,
    edition_url: body.edition_url ?? null,
    position: devo.position,
    stars: devo.stars ?? null,
    status: devo.status ?? "published",
    notion_page_id: devo.notion_page_id ?? null,
    published_at: new Date().toISOString(),
  }));

  const { data, error } = await supabase
    .from("devos")
    .upsert(rows, { onConflict: "edition_date,position" })
    .select("id, position");

  if (error) return json({ error: error.message }, 500);

  const saved = data ?? [];
  for (const devo of body.devos!) {
    const tags = devo.tags ?? [];
    if (tags.length === 0) continue;
    const match = saved.find((row) => row.position === devo.position);
    if (!match) continue;
    const { data: tagRows, error: tagError } = await supabase
      .from("tags")
      .select("id, slug")
      .in("slug", tags);
    if (tagError) return json({ error: tagError.message }, 500);
    if (!tagRows?.length) continue;
    const links = tagRows.map((tag) => ({ devo_id: match.id, tag_id: tag.id }));
    const { error: linkError } = await supabase
      .from("devo_tags")
      .upsert(links, { onConflict: "devo_id,tag_id" });
    if (linkError) return json({ error: linkError.message }, 500);
  }

  return json({ ok: true, count: saved.length, edition_date: body.edition_date });
});
