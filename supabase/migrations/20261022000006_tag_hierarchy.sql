-- Tag hierarchy. Adds nullable parent_slug and is_filter (default false).
-- Inserts four filter topics and points the 54 section tags at a parent.
-- Safe to run more than once. No table or column is dropped.

alter table public.tags
  add column if not exists parent_slug text;

alter table public.tags
  add column if not exists is_filter boolean not null default false;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'tags_parent_slug_fkey'
      and conrelid = 'public.tags'::regclass
  ) then
    alter table public.tags
      add constraint tags_parent_slug_fkey
      foreign key (parent_slug) references public.tags (slug);
  end if;
end $$;

insert into public.tags (slug, label, category, is_filter) values
  ('gospel-faith', 'Gospel & Faith', 'topic', true),
  ('love-kindness', 'Love & Kindness', 'topic', true),
  ('church-community', 'Church & Community', 'topic', true),
  ('grace-holiness', 'Grace & Holiness', 'topic', true)
on conflict (slug) do update
set label = excluded.label,
    category = excluded.category,
    is_filter = true;

update public.tags
set is_filter = true
where slug in ('courage', 'anxiety', 'fear', 'hope', 'peace', 'gratitude', 'grief', 'trust', 'prayer', 'rest', 'scripture', 'waiting', 'perseverance', 'identity', 'work', 'family', 'gospel-faith', 'love-kindness', 'church-community', 'grace-holiness');

update public.tags
set is_filter = false
where slug in ('action', 'belonging', 'calling', 'character', 'church', 'comfort', 'communion', 'community', 'discipline', 'encouragement', 'endurance', 'evangelism', 'faith', 'faithfulness', 'foundation', 'freedom', 'friendship', 'fruitfulness', 'gospel', 'grace', 'healing', 'history', 'holiness', 'honesty', 'honor', 'humility', 'influence', 'invitation', 'jesus', 'justice', 'kindness', 'leadership', 'legacy', 'love', 'power', 'priorities', 'protection', 'providence', 'refuge', 'relationships', 'salvation', 'security', 'servanthood', 'service', 'small-things', 'strength', 'surrender', 'trouble', 'value', 'vulnerability', 'weakness', 'welcome', 'worship', 'worth');

update public.tags as child
set parent_slug = map.parent
from (values
  ('action', 'courage'),
  ('belonging', 'identity'),
  ('calling', 'work'),
  ('character', 'identity'),
  ('church', 'church-community'),
  ('comfort', 'peace'),
  ('communion', 'church-community'),
  ('community', 'church-community'),
  ('discipline', 'perseverance'),
  ('encouragement', 'hope'),
  ('endurance', 'perseverance'),
  ('evangelism', 'gospel-faith'),
  ('faith', 'trust'),
  ('faithfulness', 'trust'),
  ('foundation', 'trust'),
  ('freedom', 'peace'),
  ('friendship', 'church-community'),
  ('fruitfulness', 'work'),
  ('gospel', 'gospel-faith'),
  ('grace', 'grace-holiness'),
  ('healing', 'hope'),
  ('history', 'scripture'),
  ('holiness', 'grace-holiness'),
  ('honesty', 'courage'),
  ('honor', 'identity'),
  ('humility', 'grace-holiness'),
  ('influence', 'work'),
  ('invitation', 'gospel-faith'),
  ('jesus', 'gospel-faith'),
  ('justice', 'love-kindness'),
  ('kindness', 'love-kindness'),
  ('leadership', 'work'),
  ('legacy', 'family'),
  ('love', 'love-kindness'),
  ('power', 'courage'),
  ('priorities', 'work'),
  ('protection', 'trust'),
  ('providence', 'trust'),
  ('refuge', 'peace'),
  ('relationships', 'family'),
  ('salvation', 'gospel-faith'),
  ('security', 'trust'),
  ('servanthood', 'grace-holiness'),
  ('service', 'work'),
  ('small-things', 'work'),
  ('strength', 'courage'),
  ('surrender', 'trust'),
  ('trouble', 'anxiety'),
  ('value', 'identity'),
  ('vulnerability', 'fear'),
  ('weakness', 'fear'),
  ('welcome', 'church-community'),
  ('worship', 'church-community'),
  ('worth', 'identity')
) as map(slug, parent)
where child.slug = map.slug;
