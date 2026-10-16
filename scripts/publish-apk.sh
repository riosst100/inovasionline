#!/usr/bin/env bash
# Publish a built APK to inovasionline.com/download (served by nginx from download/).
# Usage: publish-apk.sh <apk-path> <version-name> <build-number>
set -euo pipefail

APK_SRC="$1"
VERSION="$2"
BUILD="$3"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/download"
APK_NAME="inovasionline.apk"

[ -f "$APK_SRC" ] || { echo "APK not found: $APK_SRC" >&2; exit 1; }
mkdir -p "$DEST"

# Copy then rename so a download in progress never sees a half-written file.
cp "$APK_SRC" "$DEST/.$APK_NAME.tmp"
mv -f "$DEST/.$APK_NAME.tmp" "$DEST/$APK_NAME"

SIZE=$(stat -c %s "$DEST/$APK_NAME")
SHA256=$(sha256sum "$DEST/$APK_NAME" | cut -d' ' -f1)
cat > "$DEST/.release.json.tmp" <<JSON
{
  "version": "$VERSION",
  "buildNumber": $BUILD,
  "date": "$(date -Iseconds)",
  "filename": "$APK_NAME",
  "size": $SIZE,
  "sha256": "$SHA256"
}
JSON
mv -f "$DEST/.release.json.tmp" "$DEST/release.json"
chmod 644 "$DEST/$APK_NAME" "$DEST/release.json"

echo "==> Published $APK_NAME v$VERSION ($BUILD), $SIZE bytes"
