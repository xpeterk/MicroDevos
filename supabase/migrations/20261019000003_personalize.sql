-- Personalize: public style labels, private generation notes, and Mine.
-- generation_notes stays empty. Fill it later with the service role.
-- Weekly cap and monthly spend ceiling are not decided; they live in
-- function env, not in this schema.

create table public.style_profiles (
  key text primary key,
  label text not null,
  blurb text not null default '',
  kind text not null check (kind in ('style', 'classic')),
  generation_notes text not null default '',
  active boolean not null default true
);

comment on table public.style_profiles is
  'Reader-facing style and public-domain classic labels. generation_notes is server-only and ships empty.';
comment on column public.style_profiles.generation_notes is
  'Server-only writing reference. Empty until filled by the service role. Not granted to anon or authenticated.';

insert into public.style_profiles (key, label, blurb, kind, generation_notes) values
  ('purpose', 'Purpose & practical living', 'short, numbered steps', 'style', ''),
  ('invitation', 'Good news & invitation', 'clear, hopeful call to faith', 'style', ''),
  ('healing', 'Healing & faith', 'bold confidence in God''s promises', 'style', ''),
  ('grace', 'Grace & the Spirit', 'rest in grace, spiritual gifts', 'style', ''),
  ('bible', 'Bible on the go', 'quick, conversational teaching', 'style', ''),
  ('spurgeon', 'C. H. Spurgeon', 'vivid, warm, rich imagery', 'classic', ''),
  ('murray', 'Andrew Murray', 'quiet, prayer-centered depth', 'classic', ''),
  ('meyer', 'F. B. Meyer', 'devotional, character-focused', 'classic', ''),
  ('henry', 'Matthew Henry', 'plain verse commentary', 'classic', '');

alter table public.generated_devos
  add column style_key text references public.style_profiles (key),
  add column verse_refs text[] not null default '{}';

comment on column public.generated_devos.style_key is
  'Opaque style_profiles.key. The label is joined for display.';
comment on column public.generated_devos.topic_key is
  'Cache key: topic:<text> or verse:<refs>. Paired with profile_hash and style_key.';

create index generated_devos_cache_style_idx
  on public.generated_devos (profile_hash, topic_key, style_key);

create table public.mine (
  user_id uuid not null references auth.users (id) on delete cascade,
  generated_devo_id uuid not null references public.generated_devos (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, generated_devo_id)
);

comment on table public.mine is
  'Generated devotions the reader chose to keep. Distinct from favorites.';

alter table public.style_profiles enable row level security;
alter table public.mine enable row level security;

create policy "active styles are readable" on public.style_profiles
  for select to anon, authenticated
  using (active);

create policy "read own mine" on public.mine
  for select to authenticated using (auth.uid() = user_id);
create policy "insert own mine" on public.mine
  for insert to authenticated with check (auth.uid() = user_id);
create policy "delete own mine" on public.mine
  for delete to authenticated using (auth.uid() = user_id);

revoke all on public.style_profiles from anon, authenticated;
grant select (key, label, blurb, kind) on public.style_profiles to anon, authenticated;
grant all privileges on public.style_profiles to service_role;

grant select, insert, delete on public.mine to authenticated;
grant all privileges on public.mine to service_role;
revoke all on public.mine from anon;

-- Nearest-neighbor lookup used only when a provider returns a vector.
-- The fake provider leaves embeddings null, so generate-devo skips this.
create or replace function public.match_generated_devo(
  query_embedding extensions.vector(1536),
  match_style text
)
returns table (id uuid, content jsonb)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select generated_devos.id, generated_devos.content
  from public.generated_devos
  where generated_devos.style_key = match_style
    and generated_devos.embedding is not null
  order by generated_devos.embedding <=> query_embedding
  limit 1;
$$;

revoke all on function public.match_generated_devo(extensions.vector(1536), text) from public, anon, authenticated;
grant execute on function public.match_generated_devo(extensions.vector(1536), text) to service_role;
