#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# DailyHelper — Keyless 1-Command Google Play Release Script
# Usage: ./scripts/release.sh [internal|alpha|beta|production] ["Release notes"]
# =============================================================================

TRACK="${1:-internal}"
NOTES="${2:-Bug fixes and improvements.}"
PACKAGE_NAME="com.dumbmonk.dailyhelper"
EXPECTED_SHA1="60:06:1A:4C:31:A7:AE:FF:80:7D:A2:38:BB:D3:1D:3A:8C:2D:49:B4"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/daily_helper_app"
OUT_DIR="$ROOT_DIR/release_uploads"
GCLOUD_BIN="${GCLOUD_BIN:-$HOME/google-cloud-sdk/bin/gcloud}"

VERSION=$(grep '^version:' "$APP_DIR/pubspec.yaml" | awk '{print $2}')
echo "=========================================================="
echo "🚀 DailyHelper Release Pipeline: v$VERSION -> $TRACK"
echo "=========================================================="

cd "$APP_DIR"
flutter analyze
flutter test

echo "📦 Building signed App Bundle (.aab)..."
flutter build appbundle --release

mkdir -p "$OUT_DIR"
AAB_OUT="$OUT_DIR/dailyhelper-v${VERSION}-release.aab"
SYM_OUT="$OUT_DIR/dailyhelper-v${VERSION}-native-debug-symbols.zip"
APK_OUT="$OUT_DIR/dailyhelper-v${VERSION}-release.apk"

cp build/app/outputs/bundle/release/app-release.aab "$AAB_OUT"
rm -f "$SYM_OUT"
(cd build/app/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib && zip -r -q "$SYM_OUT" .)

echo "🔍 Preflight SHA1 check..."
ACTUAL_SHA1=$(keytool -printcert -jarfile "$AAB_OUT" | awk '/SHA1:/ {print $2; exit}')
if [[ "$ACTUAL_SHA1" != "$EXPECTED_SHA1" ]]; then
  echo "❌ Upload key SHA1 mismatch! Expected $EXPECTED_SHA1, got $ACTUAL_SHA1"
  exit 1
fi
echo "✅ Upload key SHA1 verified: $ACTUAL_SHA1"

echo "⬆️  Uploading to Google Play ($TRACK) via keyless IAM impersonation..."
GCLOUD_USER_TOKEN="$("$GCLOUD_BIN" auth print-access-token)" \
  node "$ROOT_DIR/scripts/upload_to_play.mjs" \
    --package "$PACKAGE_NAME" \
    --aab "$AAB_OUT" \
    --symbols "$SYM_OUT" \
    --track "$TRACK" \
    --status completed \
    --notes "$NOTES"

echo "📱 Building direct-install APK..."
flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "$APK_OUT"

echo "=========================================================="
echo "🎉 DailyHelper v$VERSION released to Google Play '$TRACK'!"
echo "   AAB:     $AAB_OUT"
echo "   Symbols: $SYM_OUT"
echo "   APK:     $APK_OUT"
echo "=========================================================="
