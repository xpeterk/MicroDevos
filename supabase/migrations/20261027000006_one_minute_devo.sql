-- 1 Minute Micro Devo: one short paragraph per devo, app only.
-- Nullable columns, no defaults. Existing rows stay valid. Nothing dropped.
alter table public.devos
  add column if not exists one_minute_text text,
  add column if not exists one_minute_verse_ref text,
  add column if not exists one_minute_verse_text text,
  add column if not exists one_minute_today text;

comment on column public.devos.one_minute_text is
  'About 130-160 words. One flowing paragraph telling the whole devo. Null or blank hides the 1 Minute Micro Devo bar.';
comment on column public.devos.one_minute_verse_ref is 'Reference for the closing verse, e.g. "Luke 6:27-28 (ESV)".';
comment on column public.devos.one_minute_verse_text is 'Full verse text for the closing verse box.';
comment on column public.devos.one_minute_today is
  'Short action line WITHOUT the label, e.g. "Pray for believers in Libya, then ask God to help you forgive one person." The app renders it after "🙏 Today:".';
