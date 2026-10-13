#!/usr/bin/env bash
# Forward backend ports to connected Android device via ADB, then run Flutter app
set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

# Find ADB executable (Linux or Windows via WSL)
ADB_CMD=""
if command -v adb >/dev/null 2>&1; then
    ADB_CMD="adb"
elif command -v adb.exe >/dev/null 2>&1; then
    ADB_CMD="adb.exe"
elif [ -f "/mnt/c/Users/hp5cd/AppData/Local/Android/Sdk/platform-tools/adb.exe" ]; then
    ADB_CMD="/mnt/c/Users/hp5cd/AppData/Local/Android/Sdk/platform-tools/adb.exe"
fi

if [ -n "$ADB_CMD" ]; then
    echo "==> Configuring ADB reverse port forwards..."
    "$ADB_CMD" reverse tcp:8000 tcp:8000 2>/dev/null || true
    "$ADB_CMD" reverse tcp:8001 tcp:8001 2>/dev/null || true
    "$ADB_CMD" reverse tcp:8002 tcp:8002 2>/dev/null || true
    "$ADB_CMD" reverse tcp:8080 tcp:8080 2>/dev/null || true
    echo "==> Active ADB reverse forwards:"
    "$ADB_CMD" reverse --list || true
fi

# If D:\inovasionline\inovasionline-apps-flutter exists, sync and run from D: drive to bypass Windows-on-WSL Gradle/Java 25 file permission issues
WIN_NATIVE_DIR="/mnt/d/inovasionline/inovasionline-apps-flutter"
if [ -d "$WIN_NATIVE_DIR" ]; then
    echo "==> Syncing changes to Windows native drive ($WIN_NATIVE_DIR)..."
    rsync -a --delete --exclude=".git" --exclude="build" --exclude=".dart_tool" --exclude=".widget_preview" "$SCRIPT_DIR/" "$WIN_NATIVE_DIR/"
    echo "==> Running Flutter on Windows native drive (D:\inovasionline\inovasionline-apps-flutter)..."
    exec cmd.exe /c "cd /d D:\inovasionline\inovasionline-apps-flutter && flutter run --flavor dev -t lib/main_dev.dart $*"
fi

# Fallback: run directly
if command -v flutter >/dev/null 2>&1 && flutter --version >/dev/null 2>&1; then
    exec flutter run --flavor dev -t lib/main_dev.dart "$@"
else
    WIN_PATH=$(wslpath -w "$SCRIPT_DIR")
    echo "==> Running Flutter via Windows host on $WIN_PATH..."
    exec cmd.exe /c "pushd $WIN_PATH && flutter run --flavor dev -t lib/main_dev.dart $*"
fi

