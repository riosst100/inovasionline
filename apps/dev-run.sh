#!/usr/bin/env bash
# Forward backend ports to connected Android device via ADB, then run Flutter app
set -e

if command -v adb >/dev/null 2>&1; then
    echo "Configuring adb reverse ports..."
    adb reverse tcp:8000 tcp:8000 || true
    adb reverse tcp:8001 tcp:8001 || true
    adb reverse tcp:8080 tcp:8080 || true
fi

flutter run --flavor dev -t lib/main_dev.dart "$@"
