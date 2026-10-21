#!/usr/bin/env bash
# Apply the migrations to a brand-new Postgres database and run the RLS checks.
# Requires PostgreSQL with the pgvector package, and a superuser via sudo -u postgres.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="${1:-micro_devos_test}"

if ! sudo -u postgres psql -d postgres -c "select 1" >/dev/null 2>&1; then
  echo "PostgreSQL is not accepting connections. Start it, then rerun this script." >&2
  echo "On Debian or Ubuntu: sudo pg_ctlcluster 16 main start" >&2
  exit 1
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${DB}' AND pid <> pg_backend_pid();" \
  >/dev/null
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "DROP DATABASE IF EXISTS \"${DB}\";"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d postgres -c "CREATE DATABASE \"${DB}\";"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/tests/plain_postgres_bootstrap.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261018000001_init.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261018000002_feed_notes_and_images.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261019000003_personalize.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261020000004_image_alt.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261021000005_devo_sections.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/migrations/20261022000006_tag_hierarchy.sql"
sudo -u postgres psql -v ON_ERROR_STOP=1 -d "${DB}" -f "${ROOT}/supabase/tests/rls_test.sql"
echo "Migrations applied from a clean database and RLS checks passed (${DB})."

# The importer's devo_tags upsert, against this same database.
sudo -u postgres env \
  HOME=/tmp \
  PATH="${PATH}" \
  PGHOST=/var/run/postgresql \
  PGUSER=postgres \
  PGDATABASE="${DB}" \
  "${ROOT}/tools/notion-import/node_modules/.bin/tsx" \
  "${ROOT}/tools/notion-import/src/write-devo-tags-pg.ts"
echo "Importer devo_tags upsert passed (${DB})."
