-- Additive. teaser is the short summary under the title, distinct from the
-- banner sentence. prayer is the closing prayer line, stored without a Today
-- label. Not applied to the hosted database with this change.

alter table public.devos
  add column if not exists teaser text not null default '';

alter table public.devos
  add column if not exists prayer text not null default '';
