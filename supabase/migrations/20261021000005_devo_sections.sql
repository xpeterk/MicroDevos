-- Optional Blinkist-style sections on a devotion.
-- Adds tables and nullable columns. Replaces the devo-level favorites
-- unique index with two partial indexes so a reader can save the whole
-- devotion and also save individual sections. Existing rows stay valid.
-- No table or column is dropped.

create table public.devo_sections (
  id uuid primary key default gen_random_uuid(),
  devo_id uuid not null references public.devos (id) on delete cascade,
  position integer not null check (position >= 1),
  title text not null,
  summary text not null default '',
  minutes integer not null default 1 check (minutes >= 1),
  verse_ref text not null default '',
  verse_text text not null default '',
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (devo_id, position)
);

comment on column public.devo_sections.body is
  'Same JSON block document as devos.body_md. Empty when the section has no body yet.';

create index devo_sections_devo_idx on public.devo_sections (devo_id, position);

create trigger devo_sections_set_updated_at
  before update on public.devo_sections
  for each row execute function public.set_updated_at();

create table public.section_tags (
  section_id uuid not null references public.devo_sections (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (section_id, tag_id)
);

alter table public.favorites
  add column section_id uuid references public.devo_sections (id) on delete cascade;

alter table public.notes
  add column section_id uuid references public.devo_sections (id) on delete cascade;

alter table public.favorites
  add constraint favorites_section_needs_devo
  check (section_id is null or devo_id is not null);

comment on column public.favorites.section_id is
  'Null saves the whole devotion. Set saves one section of that devotion.';
comment on column public.notes.section_id is
  'Null attaches the note to the whole devotion. Set anchors it to one section. The text column notes.section is still the passage key.';

drop index if exists public.favorites_user_devo_uidx;

create unique index favorites_user_devo_level_uidx
  on public.favorites (user_id, devo_id)
  where section_id is null and devo_id is not null;

create unique index favorites_user_section_uidx
  on public.favorites (user_id, section_id)
  where section_id is not null;

create index notes_section_idx on public.notes (section_id);

alter table public.devo_sections enable row level security;
alter table public.section_tags enable row level security;

create policy "devo sections are public" on public.devo_sections
  for select to anon, authenticated using (true);

create policy "section tags are public" on public.section_tags
  for select to anon, authenticated using (true);

grant select on public.devo_sections to anon, authenticated;
grant select on public.section_tags to anon, authenticated;
grant all privileges on public.devo_sections to service_role;
grant all privileges on public.section_tags to service_role;

revoke insert, update, delete, truncate on public.devo_sections from anon, authenticated;
revoke insert, update, delete, truncate on public.section_tags from anon, authenticated;
