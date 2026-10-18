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
