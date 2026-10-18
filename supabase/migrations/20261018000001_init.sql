-- Micro Devos foundation.
-- Embeddings stay null until a later job fills them.
-- Service role bypasses row-level security, so tables with no write policy
-- are writable by the service role only.

create extension if not exists vector with schema extensions;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  label text not null,
  category text not null check (category in ('topic', 'life_situation', 'emotion'))
);

create table public.devos (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  hook text not null default '',
  body_md text not null default '',
  takeaway text not null default '',
  verse_text text not null default '',
  verse_ref text not null default '',
  scriptures jsonb not null default '[]'::jsonb,
  source_url text,
  edition_date date not null,
  edition_url text,
  position integer not null check (position between 1 and 8),
  stars integer check (stars between 1 and 3),
  status text not null default 'published',
  notion_page_id text,
  embedding extensions.vector(1536),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (edition_date, position),
  unique (notion_page_id, position)
);

create index devos_edition_date_idx on public.devos (edition_date desc, position);
create index devos_search_idx on public.devos using gin (
  to_tsvector(
    'english',
    title || ' ' || hook || ' ' || coalesce(body_md, '') || ' ' || coalesce(takeaway, '')
  )
);
create index devos_embedding_hnsw
  on public.devos
  using hnsw (embedding extensions.vector_cosine_ops);

create trigger devos_set_updated_at
  before update on public.devos
  for each row execute function public.set_updated_at();

create table public.devo_tags (
  devo_id uuid not null references public.devos (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  weight real not null default 1,
  primary key (devo_id, tag_id)
);

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  age_range text,
  sex text,
  tz text,
  tier text not null default 'free',
  location text,
  location_consent_at timestamptz,
  created_at timestamptz not null default now()
);

comment on column public.profiles.location is
  'Coarse city or region. Written only after the reader opts in.';
comment on column public.profiles.location_consent_at is
  'When the reader opted in to location. Null means no consent.';

create table public.preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  age_range text,
  sex text,
  life_situations text[] not null default '{}',
  bible_versions text[] not null default '{kjv}',
  tags text[] not null default '{}',
  notify_time time not null default '07:30',
  widget_config jsonb not null default '{}'::jsonb,
  profile_hash text,
  pref_embedding extensions.vector(1536),
  updated_at timestamptz not null default now()
);

comment on column public.preferences.bible_versions is
  'Reading translation first, then any other enabled ids: esv, niv, kjv, nlt, nkjv, csb, nasb.';
comment on column public.preferences.age_range is
  'App-facing profile field. profiles.age_range mirrors it for premium onboarding.';

create index preferences_embedding_hnsw
  on public.preferences
  using hnsw (pref_embedding extensions.vector_cosine_ops);

create trigger preferences_set_updated_at
  before update on public.preferences
  for each row execute function public.set_updated_at();

create table public.generated_devos (
  id uuid primary key default gen_random_uuid(),
  profile_hash text,
  topic_key text,
  prompt_text text,
  content jsonb not null,
  model text,
  tokens_in integer,
  tokens_out integer,
  cost_usd numeric(12, 6),
  safety_status text,
  reuse_count integer not null default 0,
  embedding extensions.vector(1536),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index generated_devos_embedding_hnsw
  on public.generated_devos
  using hnsw (embedding extensions.vector_cosine_ops);
create index generated_devos_cache_idx
  on public.generated_devos (profile_hash, topic_key);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  devo_id uuid references public.devos (id) on delete cascade,
  generated_devo_id uuid references public.generated_devos (id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint favorites_one_target check (num_nonnulls(devo_id, generated_devo_id) = 1)
);

create unique index favorites_user_devo_uidx on public.favorites (user_id, devo_id);
create unique index favorites_user_generated_uidx on public.favorites (user_id, generated_devo_id);

create table public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  revenuecat_id text,
  product text,
  status text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.ai_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  generations integer not null default 0,
  tokens integer not null default 0,
  cost_usd numeric(12, 6) not null default 0,
  primary key (user_id, day)
);

create table public.verse_texts (
  version text not null,
  verse_ref text not null,
  text text not null,
  source_api text,
  fetched_at timestamptz not null default now(),
  expires_at timestamptz,
  primary key (version, verse_ref)
);

comment on table public.verse_texts is
  'Per-translation cache. KJV may be stored permanently. Other versions must honor the publisher cache limit via expires_at. Writes are service-role only.';

create table public.news_cache (
  location_key text not null,
  topic text not null,
  items jsonb not null default '[]'::jsonb,
  fetched_at timestamptz not null default now(),
  expires_at timestamptz,
  primary key (location_key, topic)
);

comment on table public.news_cache is
  'Google News RSS results for local-news devotions. Writes are service-role only.';

insert into public.tags (slug, label, category) values
  ('courage', 'Courage', 'emotion'),
  ('anxiety', 'Anxiety', 'emotion'),
  ('fear', 'Fear', 'emotion'),
  ('hope', 'Hope', 'emotion'),
  ('peace', 'Peace', 'emotion'),
  ('gratitude', 'Gratitude', 'emotion'),
  ('grief', 'Grief', 'emotion'),
  ('trust', 'Trust', 'topic'),
  ('prayer', 'Prayer', 'topic'),
  ('rest', 'Rest', 'topic'),
  ('scripture', 'Scripture', 'topic'),
  ('waiting', 'Waiting', 'topic'),
  ('perseverance', 'Perseverance', 'topic'),
  ('identity', 'Identity', 'topic'),
  ('work', 'Work', 'life_situation'),
  ('family', 'Family', 'life_situation');

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (user_id) values (new.id);
  insert into public.preferences (user_id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.tags enable row level security;
alter table public.devos enable row level security;
alter table public.devo_tags enable row level security;
alter table public.profiles enable row level security;
alter table public.preferences enable row level security;
alter table public.generated_devos enable row level security;
alter table public.favorites enable row level security;
alter table public.subscriptions enable row level security;
alter table public.ai_usage enable row level security;
alter table public.verse_texts enable row level security;
alter table public.news_cache enable row level security;

create policy "tags are public" on public.tags
  for select to anon, authenticated using (true);

create policy "devos are public" on public.devos
  for select to anon, authenticated using (true);

create policy "devo tags are public" on public.devo_tags
  for select to anon, authenticated using (true);

create policy "read own profile" on public.profiles
  for select to authenticated using (auth.uid() = user_id);
create policy "insert own profile" on public.profiles
  for insert to authenticated with check (auth.uid() = user_id);
create policy "update own profile" on public.profiles
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "read own preferences" on public.preferences
  for select to authenticated using (auth.uid() = user_id);
create policy "insert own preferences" on public.preferences
  for insert to authenticated with check (auth.uid() = user_id);
create policy "update own preferences" on public.preferences
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "read own or shared generated devos" on public.generated_devos
  for select to authenticated
  using (created_by = auth.uid() or created_by is null);

create policy "read own favorites" on public.favorites
  for select to authenticated using (auth.uid() = user_id);
create policy "insert own favorites" on public.favorites
  for insert to authenticated with check (auth.uid() = user_id);
create policy "delete own favorites" on public.favorites
  for delete to authenticated using (auth.uid() = user_id);

create policy "read own subscription" on public.subscriptions
  for select to authenticated using (auth.uid() = user_id);

create policy "read own usage" on public.ai_usage
  for select to authenticated using (auth.uid() = user_id);

create policy "verse texts are readable" on public.verse_texts
  for select to anon, authenticated using (true);

create policy "news cache is readable" on public.news_cache
  for select to authenticated using (true);

revoke insert, update, delete, truncate on public.verse_texts from anon, authenticated;
revoke insert, update, delete, truncate on public.news_cache from anon, authenticated;
revoke insert, update, delete, truncate on public.devos from anon, authenticated;
revoke insert, update, delete, truncate on public.tags from anon, authenticated;
revoke insert, update, delete, truncate on public.devo_tags from anon, authenticated;
revoke insert, update, delete, truncate on public.generated_devos from anon, authenticated;
revoke insert, update, delete, truncate on public.subscriptions from anon, authenticated;
revoke insert, update, delete, truncate on public.ai_usage from anon, authenticated;
