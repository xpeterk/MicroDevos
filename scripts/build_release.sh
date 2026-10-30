#!/usr/bin/env bash
#
# Builds the Micro Devos release APK with live Supabase credentials from .env.
# Fails with a clear error if either SUPABASE_URL or SUPABASE_ANON_KEY is missing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: Missing .env file at $ENV_FILE" >&2
  exit 1
fi

SUPABASE_URL=""
SUPABASE_ANON_KEY=""

while IFS= read -r line || [ -n "$line" ]; do
  # Strip leading and trailing whitespace
  line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
  case "$line" in
    \#*|"") continue ;;
    SUPABASE_URL=*)
      val="${line#SUPABASE_URL=}"
      val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
      SUPABASE_URL="$val"
      ;;
    SUPABASE_ANON_KEY=*)
      val="${line#SUPABASE_ANON_KEY=}"
      val="${val#\"}"; val="${val%\"}"; val="${val#\'}"; val="${val%\'}"
      SUPABASE_ANON_KEY="$val"
      ;;
  esac
done < "$ENV_FILE"

if [ -z "${SUPABASE_URL:-}" ]; then
  echo "ERROR: SUPABASE_URL is missing or empty in $ENV_FILE" >&2
  exit 1
fi

if [ -z "${SUPABASE_ANON_KEY:-}" ]; then
  echo "ERROR: SUPABASE_ANON_KEY is missing or empty in $ENV_FILE" >&2
  exit 1
fi

echo "==> Verified .env configuration: live credentials present."
cd "$PROJECT_ROOT"

echo "==> Cleaning build artifacts..."
flutter clean

echo "==> Resolving dependencies..."
flutter pub get

echo "==> Building release APK with live Supabase credentials..."
flutter build apk --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo "==> Release APK successfully built: $PROJECT_ROOT/build/app/outputs/flutter-apk/app-release.apk"
