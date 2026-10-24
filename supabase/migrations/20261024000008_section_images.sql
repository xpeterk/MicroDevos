-- Additive. image_url is the half-height banner for an expanded section.
-- Null means the expanded card shows no strip. image_alt is the description
-- of that image. Not applied to the hosted database with this change.

alter table public.devo_sections
  add column if not exists image_url text;

alter table public.devo_sections
  add column if not exists image_alt text;
