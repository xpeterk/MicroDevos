-- Plan additions for the feed: optional banner art, and private notes.
-- image_url stays null when the app should paint a placeholder.
-- A note points at exactly one of devo_id or generated_devo_id.

alter table public.devos
  add column image_url text;

comment on column public.devos.image_url is
  'Optional banner image. Null means the client paints a placeholder and does not fetch a remote image.';

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  devo_id uuid references public.devos (id) on delete cascade,
  generated_devo_id uuid references public.generated_devos (id) on delete cascade,
  body text not null,
  anchor_text text,
  anchor_start integer,
  anchor_end integer,
  section text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notes_one_target check (num_nonnulls(devo_id, generated_devo_id) = 1),
  constraint notes_anchor_range check (
    (anchor_start is null and anchor_end is null)
    or (
      anchor_start is not null
      and anchor_end is not null
      and anchor_end >= anchor_start
    )
  ),
  constraint notes_section check (
    section is null
    or section in ('hook', 'body', 'takeaway', 'verse', 'scripture')
  )
);

comment on table public.notes is
  'Private notes. anchor_text plus section lets the highlight be found again after a re-render. Null section attaches the note to the whole devotion.';

create index notes_user_updated_idx on public.notes (user_id, updated_at desc);

create trigger notes_set_updated_at
  before update on public.notes
  for each row execute function public.set_updated_at();

alter table public.notes enable row level security;

create policy "read own notes" on public.notes
  for select to authenticated using (auth.uid() = user_id);
create policy "insert own notes" on public.notes
  for insert to authenticated with check (auth.uid() = user_id);
create policy "update own notes" on public.notes
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
create policy "delete own notes" on public.notes
  for delete to authenticated using (auth.uid() = user_id);

grant select on public.notes to anon, authenticated;
grant insert, update, delete on public.notes to authenticated;
grant all privileges on public.notes to service_role;
