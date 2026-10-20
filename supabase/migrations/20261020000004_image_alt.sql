-- Alt text for the banner chosen by the optional RSS step.
-- That step updates image_url and image_alt only. Notion stays the source
-- for title, hook, body, takeaway, and Scripture.

alter table public.devos
  add column image_alt text;

comment on column public.devos.image_alt is
  'Alt text for image_url, copied from the Substack edition post. Null when no banner matched. The RSS step never writes devotion text.';
