# Micro Devos

Daily Christian micro-devotionals. Each weekday edition holds eight short devotions: a title, a one-line hook ("At a Glance"), a short reflection, a takeaway, Scripture quotes, and a featured verse.

This repository ships the app foundation, the data model, sample content that runs with no keys, the publishing path from Notion into Supabase, and Personalize (a premium generator that currently uses a fake, deterministic provider). Later milestones add recommendations, the home-screen widget, and subscriptions.

## Architecture

```
lib/
  core/         config, theme, router, Riverpod providers, local reminders
  domain/       models, repository interfaces, Notion parser, verse lookup, enrichment interfaces
  data/
    sample/     bundled JSON catalog and local favorites / preferences
    supabase/   repository implementations used when keys are present
    bible/      KJV bundle, Crossway ESV client, API.Bible client
    enrichment/ disabled embeddings, local keyword tags, and test fakes
  features/     today feed, devo, archive, favorites, settings, for_you, create, personalize
  shared/       reading layout widgets
assets/         sample devos, tags, public-domain KJV verses, Source Serif / Source Sans
supabase/       SQL migrations, ingest-devos, and generate-devo
tools/notion-import/   Notion "Micro Devos Cards" importer
```

The UI is Flutter with Riverpod and go_router, organized by feature. Reading text uses Source Serif 4; interface text uses Source Sans 3. Light and dark themes share a warm paper / olive palette. The featured verse sits in a shaded card.

Screens:

| Route | What it does |
| --- | --- |
| `/` | Today feed: a story row for the edition, a pinned filter bar, and one post per devotion. Weekends open the latest weekday edition. |
| `/story/:id` | Full-screen story for that devotion. Tap either side, or swipe up for the full page. |
| `/devo/:id` | Full devotion, share card, favorite toggle. |
| `/archive` | Search plus date chips. |
| `/favorites` | Saved tab. Liked, Notes, and Mine. Mine holds devotions this reader created. |
| `/settings` | Theme, Bible versions, tags, daily reminder time, account. |
| `/for-you` | Stub for recommendations. Create a devotion opens Personalize. |
| `/create` | Points at the top-bar Create button. Personalize is that sheet, not this route. |

**Create** in the top bar opens Personalize and drafts a new devotion. The filter bar only narrows devotions already in the feed. The sheet steps are What (Topic or Verse, with optional age and life-situation chips), Style, then Generate. The result is a feed card with like, share, note, Save to Mine, and Regenerate. Verse mode stores the reader's ESV or NIV choice. The on-sheet preview is bundled KJV and is labeled as sample text.

There is no author byline on any screen or in share text.

### Data

Repository interfaces live in `lib/domain/repositories`. `AppConfig` chooses the implementation:

- **Sample mode** (default). No `--dart-define` values. Sixteen original sample devotions and the KJV verses they quote ship in `assets/`. Favorites, notes, Bible versions, tags, and the reminder time stay in `SharedPreferences`.
- **Supabase mode.** Set `SUPABASE_URL` and `SUPABASE_ANON_KEY`. Published devotions come from Postgres. Favorites, notes, and preferences sync for a signed-in user. Email, Google, and Apple sign-in are wired and stay optional; sample mode never asks for an account. Notes whose devotion id is not a uuid (the bundled sample ids) stay on the device.

`VerseProvider` resolves the featured verse in the reader's chosen translation. The reading version is stored first in `bible_versions`. KJV is bundled and works offline. ESV calls the Crossway passage API when `ESV_API_KEY` is set. NIV, NLT, NKJV, CSB, and NASB call API.Bible when `API_BIBLE_KEY` and the matching Bible id are set. An unconfigured translation falls through to the next enabled version, then to the devotion's stored verse text.

`EmbeddingProvider` and `TaggingProvider` are the only doors for vectors and suggested tags. The app binds a disabled embedding provider, so the embedding columns stay null and no model is called. Tag suggestions use a local whole-word match against the seeded catalog. Tests substitute `FakeEmbeddingProvider` and `FakeTaggingProvider`.

### Backend

`supabase/migrations/20261018000001_init.sql` creates:

- `devos` (including nullable `image_url` and `image_alt`), `tags`, `devo_tags`
- `profiles` (optional location and `location_consent_at`)
- `preferences` (`age_range`, `sex`, `life_situations[]`, `bible_versions[]`, `tags[]`, `notify_time`, plus widget and embedding columns reserved for later milestones)
- `generated_devos`, `favorites`, `notes`, `subscriptions`, `ai_usage`
- `verse_texts`, `news_cache`

`devos.embedding` and `generated_devos.embedding` are `extensions.vector(1536)` with cosine HNSW indexes. Row-level security is enabled on every table. Readers can select published devotions, tags, and their own profile, preferences, favorites, notes, subscription, and usage rows. `verse_texts` and `news_cache` have no client write policies; inserts and updates are revoked from `anon` and `authenticated`, so only the service role can write them. The same revoke covers catalog tables the client should not mutate (`devos`, `tags`, `devo_tags`, `generated_devos`, `subscriptions`, `ai_usage`).

The `ingest-devos` edge function accepts a POST of one edition (1–8 devotions) and upserts on `(edition_date, position)`. Callers send the shared secret in `x-ingest-secret`. JWT verification is off for that function (`supabase/config.toml`).

A new auth user gets a `profiles` row and a `preferences` row from a trigger.

### Plan additions

`supabase/migrations/20261018000002_feed_notes_and_images.sql` adds two things on top of the foundation schema:

- `devos.image_url` is nullable text. Sample devotions leave it null. The feed paints a gradient placeholder and does not load a remote image.
- `supabase/migrations/20261020000004_image_alt.sql` adds nullable `devos.image_alt`. The optional RSS step below is the only writer. It sets `image_url` and `image_alt` and does not change devotion text.
- `notes` stores a private note on exactly one of `devo_id` or `generated_devo_id`. Columns are `body`, optional `anchor_text`, `anchor_start`, `anchor_end`, and a `section` key (`hook`, `body`, `takeaway`, `verse`, `scripture`) so a highlight can be found again after a re-render. A null section attaches the note to the whole devotion. Row-level security lets a signed-in reader select, insert, update, and delete only their own rows.

With no Supabase session, likes and notes stay in `SharedPreferences`. Signing in syncs favorites through the existing table and pushes notes whose target id is a uuid. Personalized devotions saved on this phone stay in `SharedPreferences` under Mine until a signed-in reader saves them to `public.mine`.

### Personalize

`supabase/migrations/20261019000003_personalize.sql` adds:

- `style_profiles` (`key`, `label`, `blurb`, `kind` of `style` or `classic`, `generation_notes`, `active`). The nine seed rows ship with `generation_notes` empty. Fill that column later with the service role. Row-level security lets anonymous and signed-in readers select active rows, and the column grant is only `key`, `label`, `blurb`, and `kind`. `generation_notes` is not granted to `anon` or `authenticated`.
- `generated_devos.style_key` and `generated_devos.verse_refs`, plus a cache index on `(profile_hash, topic_key, style_key)`.
- `mine`, a reader's saved generated devotions, separate from favorites.
- `match_generated_devo`, a service-role nearest-neighbor lookup. The fake provider returns no embedding, so the function skips that lookup.

The `generate-devo` edge function requires a signed-in reader (`verify_jwt = true`). It checks `profiles.tier = 'premium'`, then the weekly per-user cap and the global monthly spend ceiling. Both limits are placeholders and are not decided:

| Env | Default | Meaning |
| --- | --- | --- |
| `GENERATION_PROVIDER` | `fake` | Which `GenerationProvider` to construct. Only `fake` exists. |
| `WEEKLY_GENERATION_CAP` | `5` | Per-user generations since Monday. Not decided. |
| `MONTHLY_SPEND_CEILING_USD` | `25` | Sum of `ai_usage.cost_usd` since the first of the month, across readers. Not decided. |

A cache hit on `(profile_hash, topic_key, style_key)` increments `reuse_count` and does not add a generation. Otherwise the provider returns the standard shape (hook, title, two short sections, two Scripture quotes, a verse callout, a next step). The safety check then requires those Scripture references. In Verse mode every quote and the callout must overlap a verse the reader chose. In topic mode the draft needs two quotes with text, and the callout has to be one of those quotes. A draft that fails is not stored and does not count as a generation. No other theology rule is applied.

A generated devotion can include a short help note under the next step. `HELP_NOTE` and `HELP_NOTE_TRIGGERS` configure the sentence and the topic list. When those env vars are unset, the note is the placeholder below and it shows when the topic or a life-situation chip contains health, illness, grief, depression, anxiety, abuse, or self-harm. The wording and the trigger list are pending final approval.

> If you're struggling, please reach out to a pastor, a trusted friend, or a doctor. In the US, call or text 988 any time.

The app calls `generate-devo` when a reader is signed in. With no Supabase session it uses the same fake provider in-process, so the flow runs with no key and no paid call.

To plug in a real provider later, implement `GenerationProvider` in `supabase/functions/generate-devo/provider.ts` (and the Dart interface in `lib/domain/personalize/personalize_engine.dart` if sample mode should match). Read any model key from the function environment, never from the app. Return the same draft shape. Register the name in `providerFromEnv`, and set `GENERATION_PROVIDER` to that name. Leave `generation_notes` as the server-only writing reference for that provider. Do not add a model key to `.env.example` until that provider exists.

## Setup

Install the Flutter SDK (3.47 or newer, Dart 3.13) from the Flutter install page for your OS and add it to `PATH`. Android builds need the Android SDK (`ANDROID_HOME`) and an accepted SDK license. iOS builds need Xcode on macOS. Nothing in this repo depends on a particular editor.

```bash
flutter pub get
flutter run
```

Android device or emulator:

```bash
flutter run -d android
flutter build apk --debug
```

The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. A smaller installable build, signed with the debug key until a release keystore exists:

```bash
flutter build apk --release
```

That file is `build/app/outputs/flutter-apk/app-release.apk`.

### Install the APK on an Android phone

Copy `app-release.apk` to the phone and open it, or install over USB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

On the phone, allow installs from the app that opens the file (Files, Chrome, or Drive): Settings, then Apps or Security, then the permission for unknown or external apps. The installed app opens on the bundled sample devotions and does not need keys.

iOS, on a Mac:

```bash
flutter run -d ios
flutter build ios --no-codesign
```

The iOS project is `ios/`. The URL scheme is `com.microdevos.microdevos`, and the display name is Micro Devos.

Sample mode needs no keys. The app opens Today on the latest bundled weekday edition.

To point the app at Supabase and optional Bible APIs:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY \
  --dart-define=ESV_API_KEY=YOUR_ESV_KEY \
  --dart-define=API_BIBLE_KEY=YOUR_API_BIBLE_KEY \
  --dart-define=API_BIBLE_ID_NIV= \
  --dart-define=API_BIBLE_ID_NLT= \
  --dart-define=API_BIBLE_ID_NKJV= \
  --dart-define=API_BIBLE_ID_CSB= \
  --dart-define=API_BIBLE_ID_NASB=
```

### Local database

Hosted Supabase: run the migrations in order in the SQL editor, or `supabase db push` from the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started). `supabase start` then `supabase db reset` applies the same files on a local Supabase stack (that path needs Docker).

1. `supabase/migrations/20261018000001_init.sql`
2. `supabase/migrations/20261018000002_feed_notes_and_images.sql`
3. `supabase/migrations/20261019000003_personalize.sql`

Plain Postgres 16 with pgvector, from a new database:

```bash
bash supabase/tests/apply_and_test.sh
```

That script drops and creates `micro_devos_test`, applies `supabase/tests/plain_postgres_bootstrap.sql` (auth stub and roles that hosted Supabase already has), applies the migration, and checks row-level security: a reader sees only their own preferences and favorites, published devos are readable without signing in, and an upsert on `(notion_page_id, position)` updates the existing row. It then runs the importer's `devo_tags` upsert against that database (the fixture card, written twice so the second write does not duplicate rows). PostgreSQL has to be running first. Pass another database name as the first argument if you want one.

Set the edge function secret `INGEST_SHARED_SECRET` in the project, then deploy:

```bash
supabase functions deploy ingest-devos --no-verify-jwt
supabase functions deploy generate-devo
```

`generate-devo` keeps JWT verification on. Set `GENERATION_PROVIDER=fake` (the default), `WEEKLY_GENERATION_CAP`, and `MONTHLY_SPEND_CEILING_USD` in the function environment. The two caps are placeholders. The fake provider does not call a model and does not need an API key.

Example body:

```json
{
  "edition_date": "2026-10-16",
  "edition_url": "https://microdevos.substack.com/p/example",
  "devos": [
    {
      "position": 1,
      "title": "A Refuge That Does Not Move",
      "hook": "The refuge is a person, and he is already here.",
      "body_md": "Reflection markdown.",
      "takeaway": "Name the trouble, then say the verse once, slowly.",
      "verse_ref": "Psalm 46:1",
      "verse_text": "God is our refuge and strength...",
      "scriptures": [{ "reference": "Psalm 46:1", "text": "..." }],
      "tags": ["courage", "fear"],
      "status": "published"
    }
  ]
}
```

```bash
curl -X POST "$SUPABASE_URL/functions/v1/ingest-devos" \
  -H "content-type: application/json" \
  -H "x-ingest-secret: $INGEST_SHARED_SECRET" \
  -d @edition.json
```

OAuth redirect used by the app: `com.microdevos.microdevos://login-callback`. Enable Email, Google, and Apple in the Supabase Auth dashboard and add that redirect URL before sign-in will succeed.

### Daily reminder

Settings can turn on a local notification at a chosen time (default 7:30, off until the reader opts in). The schedule uses inexact alarms and is stored on the device. Signing in copies the time into `preferences.notify_time`.

## Notion import

`tools/notion-import` reads the Notion data source **Micro Devos Cards** (Idea, Date, Status, Stars, URL). The page body supplies the hook, `## N · Title` sections, the takeaway, Scripture, the verse box, and the Substack edition link.

Cards import only when they have an edition link on `microdevos.substack.com` or `microdevotionals.substack.com`. Status `Ideas` and `AI-Ideas`, and non-devotion pages such as `Prompt`, are skipped. Rows upsert on `(notion_page_id, position)`.

Dry run against the bundled card fixture. This needs no Notion token and does not touch Supabase:

```bash
cd tools/notion-import
npm install
npm run import -- --dry-run --fixture fixtures/sample-cards.json --out out/devos.json
```

The fixture uses the Micro Devos Cards fields (Idea, Date, Status, Stars, URL) and a page body with an At a Glance hook, a `## N · Title` heading, a takeaway, a 📖 VERSE callout, and an Edition link. Ideas, AI-Ideas, Prompt pages, and cards without an Edition link are skipped. A live import upserts on `(notion_page_id, position)`.

```bash
export NOTION_TOKEN=secret_...
export SUPABASE_URL=https://YOUR_PROJECT.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=...
# optional; defaults to the Micro Devos Cards data source
export NOTION_DATA_SOURCE_ID=515d5d5d-b81b-4751-a025-d2c0734e3f60

npm run import -- --dry-run --out out/devos.json --limit 5
npm run import
npm test
npm run typecheck
```

`--dry-run` writes `{ imported, skipped }` JSON and does not touch Supabase. The same parser rules are covered by Dart tests in `test/notion_parser_test.dart` and by `src/parse.test.ts` and `src/pipeline.test.ts`. Node 20 or newer is enough for the importer.

### Banner images from the edition feed

Notion stays the source for the hook, body, takeaway, and Scripture. `--rss` is an optional second step. It reads the public Substack feed, matches each post to the edition date in its title, and finds the per-devotion banner (the Substack CDN `src`, plus the image alt). The first image in a post is the edition cover and is skipped. The next images are matched to positions 1–8 by the `Devotion N:` label, or by image order when a label is missing. A unique title match wins over that position when the feed is applied to rows already imported from Notion.

The step updates only `devos.image_url` and `devos.image_alt`. Running it again writes the same values. If a position has no banner, the value stays null and the command logs a warning. RSS prose is never copied into the devotion text columns.

```bash
cd tools/notion-import
npm run import -- --rss --dry-run
npm run import -- --rss --images-only
npm run import -- --rss
```

`--rss --dry-run` without a card fixture only reads the feed and writes `out/rss-banners.json`. It does not need a Notion token or Supabase. `--rss-fixture fixtures/substack-feed.xml` uses the saved feed instead of the network. `--rss` without `--dry-run` imports Notion cards first, then sets banner columns. `--images-only` sets banners for rows already in Supabase and does not read Notion. `RSS_FEED_URL` overrides the default feed, `https://microdevotionals.substack.com/feed`.

## Environment variables

| Name | Used by |
| --- | --- |
| `SUPABASE_URL` | App (`--dart-define`), importer, ingest deploy |
| `SUPABASE_ANON_KEY` | App (`--dart-define`). Passed to Supabase as the publishable key. |
| `SUPABASE_SERVICE_ROLE_KEY` | Notion importer only. Never ship this in the app. |
| `NOTION_TOKEN` | Notion importer |
| `NOTION_DATA_SOURCE_ID` | Importer. Defaults to Micro Devos Cards. |
| `RSS_FEED_URL` | Optional banner step. Defaults to `https://microdevotionals.substack.com/feed`. |
| `INGEST_SHARED_SECRET` | `ingest-devos` edge function. Not used by the app. |
| `GENERATION_PROVIDER` | `generate-devo`. Default `fake`. No other provider is implemented. |
| `WEEKLY_GENERATION_CAP` | `generate-devo`. Placeholder default `5`. Not decided. |
| `MONTHLY_SPEND_CEILING_USD` | `generate-devo`. Placeholder default `25`. Not decided. |
| `HELP_NOTE` | `generate-devo`. Help line under the next step. Pending final approval. |
| `HELP_NOTE_TRIGGERS` | `generate-devo`. Comma-separated topic words that show the help line. Pending final approval. |
| `ESV_API_KEY` | App (`--dart-define`), Crossway ESV |
| `API_BIBLE_KEY` | App (`--dart-define`) |
| `API_BIBLE_ID_NIV` `API_BIBLE_ID_NLT` `API_BIBLE_ID_NKJV` `API_BIBLE_ID_CSB` `API_BIBLE_ID_NASB` | App (`--dart-define`) |

Copy `.env.example` when you want a local checklist. `.env` is gitignored. There is no embedding or model API key. The embedding provider stays disabled, and Personalize uses the fake provider.

## Tests

```bash
flutter analyze
flutter test
```

`flutter test` covers the Notion body parser (including the verse-box card), the sample repository (search, dates, share text, favorites, preferences), Bible-version selection, KJV lookup, the embedding and tagging providers, the Personalize cap and cache, and a check that reader-facing style labels do not contain a person's name. The importer's TypeScript parser, fixture import, and saved Substack feed fixture are tested with `npm test` inside `tools/notion-import`. Database checks, including the grant that hides `generation_notes` from anonymous readers:

```bash
bash supabase/tests/apply_and_test.sh
```

Debug Android APK:

```bash
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. iOS is part of the project (`ios/`) with the same URL scheme and display name. Compile it on macOS with `flutter build ios --no-codesign`.

## Roadmap

1. **Foundation** (this milestone). App shell, sample and Supabase data, verse providers, Notion import, ingest function, local reminder.
2. **Premium generator.** Personalize is in the app and in `generate-devo`, backed by the fake provider. Scripture anchoring is the safety check. A real provider, the weekly cap, the monthly ceiling, and the help-note wording are still open. Local news is not part of this flow.
3. **Recommendations.** "For You" ranks published and generated devotions with the pgvector embeddings already on `devos` and `generated_devos`, using the reader's tags and life situations.
4. **Home-screen widget.** `home_widget`, with Android Glance and iOS WidgetKit, showing the featured verse or the next unread devotion.
5. **Subscriptions.** RevenueCat products mapped onto the `subscriptions` table, gating Create and the widget.
6. **Store prep.** Store listings, privacy nutrition labels, notification copy review, Bible-text license confirmation, and release builds for Play and the App Store.

## Owner keys and decisions still open

The app runs on sample data without any of these. Production needs:

- A Supabase project (URL, anon key, service role) and the Auth providers above.
- A Notion integration token shared with the Micro Devos Cards database.
- `INGEST_SHARED_SECRET` for the daily publishing pipeline.
- An ESV API key from Crossway, and confirmation that the license covers a distributed app.
- An API.Bible key plus a Bible id for each of NIV, NLT, NKJV, CSB, and NASB. NIV in particular needs the publisher's approval.
- Product decisions still open: the weekly generation cap, the monthly spend ceiling, price, the help-note wording and triggers (pending final approval), any further safety rules beyond Scripture anchoring (`generation_notes` stays empty until filled with the service role), the public store name, and which translations ship on day one.
