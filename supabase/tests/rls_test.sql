-- Proves the foundation policies on a database that just applied the migration.
-- Fails the session with an exception when a check does not hold.

do $$
declare
  user_a uuid := '11111111-1111-4111-8111-111111111111';
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  devo uuid;
  n integer;
  embedding_type text;
begin
  select format_type(a.atttypid, a.atttypmod)
    into embedding_type
  from pg_attribute a
  join pg_class c on c.oid = a.attrelid
  join pg_namespace ns on ns.oid = c.relnamespace
  where ns.nspname = 'public'
    and c.relname = 'devos'
    and a.attname = 'embedding';
  if embedding_type not like '%1536%' then
    raise exception 'devos.embedding type is %, expected vector(1536)', embedding_type;
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'devos'
      and column_name = 'image_url'
      and is_nullable = 'YES'
  ) then
    raise exception 'devos.image_url is missing or not nullable';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'devos'
      and column_name = 'image_alt'
      and is_nullable = 'YES'
  ) then
    raise exception 'devos.image_alt is missing or not nullable';
  end if;

  insert into auth.users (id, email) values
    (user_a, 'reader-a@example.com'),
    (user_b, 'reader-b@example.com');

  insert into public.devos (
    title, hook, body_md, takeaway, verse_text, verse_ref,
    edition_date, position, notion_page_id, status
  ) values (
    'First title', 'A hook', 'A body', 'A step',
    'God is our refuge and strength.', 'Psalm 46:1',
    '2026-09-30', 1, 'notion-page-rls', 'published'
  );

  insert into public.devos (
    title, hook, body_md, takeaway, verse_text, verse_ref,
    edition_date, position, notion_page_id, status
  ) values (
    'Updated title', 'A hook', 'A body', 'A step',
    'God is our refuge and strength.', 'Psalm 46:1',
    '2026-09-30', 1, 'notion-page-rls', 'published'
  )
  on conflict (notion_page_id, position) do update
    set title = excluded.title,
        hook = excluded.hook,
        updated_at = now();

  select count(*) into n from public.devos where notion_page_id = 'notion-page-rls';
  if n <> 1 then
    raise exception 'upsert on notion_page_id, position inserted % rows', n;
  end if;
  select id into devo from public.devos where notion_page_id = 'notion-page-rls';
  if (select title from public.devos where id = devo) <> 'Updated title' then
    raise exception 'upsert did not replace the title';
  end if;

  perform set_config('request.jwt.claim.sub', user_a::text, true);
  set local role authenticated;

  update public.preferences
    set tags = '{hope}'
    where user_id = user_a;
  get diagnostics n = row_count;
  if n <> 1 then
    raise exception 'user A could not update own preferences (updated %)', n;
  end if;

  update public.preferences
    set tags = '{fear}'
    where user_id = user_b;
  get diagnostics n = row_count;
  if n <> 0 then
    raise exception 'user A updated user B preferences';
  end if;

  select count(*) into n from public.preferences;
  if n <> 1 then
    raise exception 'user A saw % preference rows', n;
  end if;

  select count(*) into n from public.profiles;
  if n <> 1 then
    raise exception 'user A saw % profile rows', n;
  end if;

  insert into public.favorites (user_id, devo_id) values (user_a, devo);

  select count(*) into n from public.favorites;
  if n <> 1 then
    raise exception 'user A saw % favorite rows', n;
  end if;

  begin
    insert into public.favorites (user_id, devo_id) values (user_b, devo);
    raise exception 'user A inserted a favorite for user B';
  exception
    when insufficient_privilege then
      null;
  end;

  select count(*) into n from public.devos;
  if n < 1 then
    raise exception 'authenticated reader could not read devos';
  end if;

  begin
    insert into public.devos (
      title, edition_date, position, notion_page_id
    ) values (
      'Nope', '2026-10-17', 1, 'should-fail'
    );
    raise exception 'authenticated reader inserted a devo';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.verse_texts (version, verse_ref, text)
    values ('kjv', 'Psalm 46:1', 'cached');
    raise exception 'authenticated reader wrote verse_texts';
  exception
    when insufficient_privilege then
      null;
  end;

  insert into public.notes (
    user_id, devo_id, body, anchor_text, anchor_start, anchor_end, section
  ) values (
    user_a, devo, 'Sit quietly.', 'God is our refuge', 0, 17, 'verse'
  );

  select count(*) into n from public.notes;
  if n <> 1 then
    raise exception 'user A saw % note rows', n;
  end if;

  select count(*) into n
  from public.notes
  where anchor_text = 'God is our refuge'
    and anchor_start = 0
    and anchor_end = 17
    and section = 'verse';
  if n <> 1 then
    raise exception 'note anchor columns were not stored';
  end if;

  begin
    insert into public.notes (user_id, devo_id, body)
    values (user_b, devo, 'not mine');
    raise exception 'user A inserted a note for user B';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.notes (user_id, body)
    values (user_a, 'missing target');
    raise exception 'note with no devotion target was inserted';
  exception
    when check_violation then
      null;
  end;
end
$$;

do $$
declare
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  n integer;
begin
  perform set_config('request.jwt.claim.sub', user_b::text, true);
  set local role authenticated;

  select count(*) into n from public.favorites;
  if n <> 0 then
    raise exception 'user B saw % favorite rows', n;
  end if;

  select count(*) into n from public.notes;
  if n <> 0 then
    raise exception 'user B saw % note rows', n;
  end if;

  select count(*) into n from public.preferences;
  if n <> 1 then
    raise exception 'user B saw % preference rows', n;
  end if;

  select count(*) into n
  from public.preferences
  where tags = '{hope}';
  if n <> 0 then
    raise exception 'user B saw user A preferences';
  end if;

  select count(*) into n from public.devos;
  if n < 1 then
    raise exception 'user B could not read public devos';
  end if;
end
$$;

do $$
declare
  n integer;
begin
  set local role anon;

  select count(*) into n from public.devos where notion_page_id = 'notion-page-rls';
  if n <> 1 then
    raise exception 'anon saw % devo rows, expected the published row', n;
  end if;

  select count(*) into n from public.preferences;
  if n <> 0 then
    raise exception 'anon saw preferences';
  end if;

  select count(*) into n from public.favorites;
  if n <> 0 then
    raise exception 'anon saw favorites';
  end if;

  select count(*) into n from public.notes;
  if n <> 0 then
    raise exception 'anon saw notes';
  end if;

  begin
    insert into public.notes (user_id, devo_id, body)
    select '11111111-1111-4111-8111-111111111111', id, 'anon note'
    from public.devos
    where notion_page_id = 'notion-page-rls';
    raise exception 'anon inserted a note';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.news_cache (location_key, topic, items)
    values ('city', 'peace', '[]'::jsonb);
    raise exception 'anon wrote news_cache';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

do $$
declare
  n integer;
begin
  set local role service_role;
  insert into public.verse_texts (version, verse_ref, text, source_api)
  values ('kjv', 'Psalm 46:1', 'God is our refuge and strength.', 'test');
  select count(*) into n from public.verse_texts where verse_ref = 'Psalm 46:1';
  if n <> 1 then
    raise exception 'service role could not write verse_texts';
  end if;
end
$$;

-- Personalize: public style labels, hidden generation notes, private Mine.
do $$
declare
  n integer;
  label_list text;
begin
  set local role anon;

  select count(*) into n from (
    select key, label, blurb, kind from public.style_profiles
  ) styles;
  if n <> 9 then
    raise exception 'anon saw % style rows, expected 9', n;
  end if;

  select string_agg(label, '|' order by label) into label_list
  from public.style_profiles
  where kind = 'style';
  if label_list <> 'Bible on the go|Good news & invitation|Grace & the Spirit|Healing & faith|Purpose & practical living' then
    raise exception 'style labels are %', label_list;
  end if;

  if exists (
    select 1 from public.style_profiles
    where kind = 'style'
      and (
        label ~ '\m[A-Z][a-z]+ [A-Z][a-z]+\M'
        or label ~* '(spurgeon|murray|meyer|henry)'
      )
  ) then
    raise exception 'a style label contains a person name';
  end if;

  select string_agg(label, '|' order by key) into label_list
  from public.style_profiles
  where kind = 'classic';
  if label_list <> 'Matthew Henry|F. B. Meyer|Andrew Murray|C. H. Spurgeon' then
    raise exception 'classic labels are %', label_list;
  end if;

  begin
    perform generation_notes from public.style_profiles;
    raise exception 'anon read generation_notes';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.mine (user_id, generated_devo_id)
    values (
      '11111111-1111-4111-8111-111111111111',
      '00000000-0000-4000-8000-000000000001'
    );
    raise exception 'anon inserted mine';
  exception
    when insufficient_privilege then
      null;
  end;
end
$$;

do $$
declare
  user_a uuid := '11111111-1111-4111-8111-111111111111';
  user_b uuid := '22222222-2222-4222-8222-222222222222';
  devo uuid;
  n integer;
  notes text;
begin
  set local role service_role;

  select coalesce(string_agg(generation_notes, ''), '') into notes
  from public.style_profiles;
  if notes <> '' then
    raise exception 'generation_notes should ship empty';
  end if;

  insert into public.generated_devos (
    content, created_by, style_key, topic_key, profile_hash
  ) values (
    '{"title":"Steady Ground on a First Morning"}'::jsonb,
    user_a,
    'purpose',
    'topic:job',
    '|'
  ) returning id into devo;

  insert into public.mine (user_id, generated_devo_id) values (user_a, devo);

  perform set_config('request.jwt.claim.sub', user_b::text, true);
  set local role authenticated;

  select count(*) into n from public.mine;
  if n <> 0 then
    raise exception 'user B saw % mine rows', n;
  end if;
end
$$;
