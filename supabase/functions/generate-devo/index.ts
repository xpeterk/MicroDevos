import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  providerFromEnv,
  ScriptureAnchorChecker,
  ScriptureAnchorException,
  helpNoteFor,
  type GenerateInput,
  type GenerationDraft,
} from "./provider.ts";

// WEEKLY_GENERATION_CAP and MONTHLY_SPEND_CEILING_USD are placeholders.
// The per-user cap and the global monthly spend ceiling are not decided.

type Body = {
  source?: string;
  topic?: string;
  verse_refs?: string[];
  style_key?: string;
  age_range?: string | null;
  life_situations?: string[];
  bible_version?: string | null;
  regenerate?: boolean;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function weekStart(now: Date): string {
  const day = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const delta = (day.getUTCDay() + 6) % 7;
  day.setUTCDate(day.getUTCDate() - delta);
  return day.toISOString().slice(0, 10);
}

function monthStart(now: Date): string {
  return new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1))
    .toISOString()
    .slice(0, 10);
}

function topicKey(input: GenerateInput): string {
  if (input.verseMode) {
    return `verse:${input.verseRefs.map((ref) => ref.trim().toLowerCase()).join("|")}`;
  }
  return `topic:${input.topic.trim().toLowerCase()}`;
}

function profileHash(input: GenerateInput): string {
  const life = [...input.lifeSituations].sort();
  return `${input.ageRange ?? ""}|${life.join(",")}`;
}

function contentOf(draft: GenerationDraft) {
  return {
    title: draft.title,
    hook: draft.hook,
    sections: draft.sections,
    structured_sections: draft.structured_sections ?? [],
    takeaway: draft.takeaway,
    verse_text: draft.verse_text,
    verse_ref: draft.verse_ref,
    scriptures: draft.scriptures,
    one_minute_text: draft.one_minute_text ?? null,
    one_minute_verse_ref: draft.one_minute_verse_ref ?? null,
    one_minute_verse_text: draft.one_minute_verse_text ?? null,
    one_minute_today: draft.one_minute_today ?? null,
    prayer: draft.prayer ?? null,
    help_note: draft.help_note ?? null,
  };
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json({ error: "Supabase credentials are not configured" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "Unauthorized" }, 401);
  const userId = userData.user.id;

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid JSON" }, 400);
  }

  const styleKey = body.style_key?.trim() ?? "";
  if (!styleKey) return json({ error: "style_key is required" }, 400);
  const verseMode = body.source === "verse";
  const topic = body.topic?.trim() ?? "";
  const verseRefs = (body.verse_refs ?? []).map((ref) => ref.trim()).filter(Boolean);
  if (!verseMode && !topic) return json({ error: "topic is required" }, 400);
  if (verseMode && verseRefs.length === 0) {
    return json({ error: "verse_refs is required" }, 400);
  }

  const input: GenerateInput = {
    verseMode,
    topic,
    verseRefs,
    styleKey,
    ageRange: body.age_range ?? null,
    lifeSituations: body.life_situations ?? [],
    generationNotes: "",
    bibleVersion: body.bible_version ?? null,
  };

  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: profile } = await admin
    .from("profiles")
    .select("tier")
    .eq("user_id", userId)
    .maybeSingle();
  if (profile?.tier !== "premium") {
    return json({ error: "Premium required" }, 403);
  }

  const weeklyCap = Number(Deno.env.get("WEEKLY_GENERATION_CAP") ?? "5");
  const monthlyCeiling = Number(Deno.env.get("MONTHLY_SPEND_CEILING_USD") ?? "25");
  const now = new Date();
  const monday = weekStart(now);
  const month = monthStart(now);

  const { data: weekRows } = await admin
    .from("ai_usage")
    .select("generations, cost_usd, day")
    .eq("user_id", userId)
    .gte("day", monday);
  const used = (weekRows ?? []).reduce(
    (sum, row) => sum + Number(row.generations ?? 0),
    0,
  );

  const { data: spendRows } = await admin
    .from("ai_usage")
    .select("cost_usd")
    .gte("day", month);
  const spend = (spendRows ?? []).reduce(
    (sum, row) => sum + Number(row.cost_usd ?? 0),
    0,
  );

  if (used >= weeklyCap) {
    return json({ error: "Weekly cap reached", used, weekly_cap: weeklyCap }, 429);
  }
  if (spend >= monthlyCeiling) {
    return json(
      { error: "Monthly spend ceiling reached", spend, ceiling: monthlyCeiling },
      429,
    );
  }

  const key = topicKey(input);
  const hash = profileHash(input);

  const { data: style } = await admin
    .from("style_profiles")
    .select("key, label, kind, generation_notes")
    .eq("key", styleKey)
    .maybeSingle();
  if (!style) return json({ error: "Unknown style" }, 400);

  const inputWithNotes: GenerateInput = {
    ...input,
    generationNotes: style.generation_notes ?? "",
    bibleVersion: body.bible_version ?? null,
  };

  if (!body.regenerate) {
    const { data: cached } = await admin
      .from("generated_devos")
      .select("id, content, reuse_count, style_key")
      .eq("profile_hash", hash)
      .eq("topic_key", key)
      .eq("style_key", styleKey)
      .limit(1)
      .maybeSingle();
    if (cached) {
      const reuse = Number(cached.reuse_count ?? 0) + 1;
      await admin.from("generated_devos").update({ reuse_count: reuse }).eq("id", cached.id);
      return json({
        devo: { id: cached.id, ...(cached.content as object) },
        cache_hit: true,
        cap: { used, weekly: weeklyCap, left: Math.max(weeklyCap - used, 0) },
      });
    }
  }

  const provider = providerFromEnv();
  const safety = new ScriptureAnchorChecker();
  let draft: GenerationDraft;
  try {
    draft = safety.review(await provider.generate(inputWithNotes), inputWithNotes);
  } catch (error) {
    if (error instanceof ScriptureAnchorException) {
      return json({ error: error.message }, 422);
    }
    throw error;
  }
  draft = { ...draft, help_note: helpNoteFor(inputWithNotes) };

  // Nearest neighbor runs only when a provider returns a vector.
  // The fake provider leaves embedding null, so this lookup is skipped.
  if (draft.embedding && draft.embedding.length > 0) {
    const vector = `[${draft.embedding.join(",")}]`;
    const { data: neighbors } = await admin.rpc("match_generated_devo", {
      query_embedding: vector,
      match_style: styleKey,
    });
    if (Array.isArray(neighbors) && neighbors.length > 0) {
      return json({ devo: neighbors[0], cache_hit: true, neighbor: true });
    }
  }

  const { data: inserted, error: insertError } = await admin
    .from("generated_devos")
    .insert({
      profile_hash: hash,
      topic_key: key,
      verse_refs: verseRefs,
      style_key: styleKey,
      prompt_text: input.verseMode ? verseRefs.join(", ") : topic,
      content: {
        ...contentOf(draft),
        style_key: styleKey,
        style_label: style.label,
        style_kind: style.kind,
        prompt_label: input.verseMode ? verseRefs.join(", ") : topic,
        bible_version: body.bible_version ?? null,
      },
      model: provider.name,
      tokens_in: draft.tokens_in,
      tokens_out: draft.tokens_out,
      cost_usd: draft.cost_usd,
      safety_status: "pass",
      created_by: userId,
    })
    .select("id, content")
    .single();
  if (insertError || !inserted) {
    return json({ error: insertError?.message ?? "Insert failed" }, 500);
  }

  const today = now.toISOString().slice(0, 10);
  const { data: usage } = await admin
    .from("ai_usage")
    .select("generations, tokens, cost_usd")
    .eq("user_id", userId)
    .eq("day", today)
    .maybeSingle();
  await admin.from("ai_usage").upsert({
    user_id: userId,
    day: today,
    generations: Number(usage?.generations ?? 0) + 1,
    tokens: Number(usage?.tokens ?? 0) + draft.tokens_in + draft.tokens_out,
    cost_usd: Number(usage?.cost_usd ?? 0) + draft.cost_usd,
  });

  return json({
    devo: { id: inserted.id, ...(inserted.content as object) },
    cache_hit: false,
    cap: { used: used + 1, weekly: weeklyCap, left: Math.max(weeklyCap - used - 1, 0) },
  });
});
