#!/usr/bin/env bash
# Run the app on a physical Android phone connected via USB.
# Usage (from repo root): ./run-usb.sh [device-id] [extra flutter args]
#   (without device-id, the first physical USB device is used)
set -e
cd "$(dirname "$0")/apps"

command -v adb >/dev/null || { echo "[ERROR] adb not found in PATH"; exit 1; }

# Pick device: first arg if it looks like a serial, else first non-emulator "device".
if [ -n "$1" ] && [[ "$1" != -* ]]; then
  DEVICE="$1"; shift
else
  DEVICE=$(adb devices | tr -d '\r' | awk 'NR>1 && $2=="device" && $1 !~ /^emulator-/ {print $1; exit}')
fi
if [ -z "$DEVICE" ]; then
  echo "[ERROR] No USB device found. Enable USB debugging, connect the phone, and accept the RSA prompt."
  adb devices -l
  exit 1
fi
echo "==> Using device: $DEVICE"

# pubspec.yaml bundles .env, .env.dev and .env.prod as assets, so all three must exist (gitignored).
[ -f .env ]      || cp .env.example .env
[ -f .env.dev ]  || cp .env.example .env.dev
[ -f .env.prod ] || cp .env.prod.example .env.prod

# adb reverse resets on every USB reconnect, so set it up before each run.
for p in 8000 8001 8002 8080; do adb -s "$DEVICE" reverse tcp:$p tcp:$p; done
adb -s "$DEVICE" reverse --list

flutter pub get
exec flutter run -d "$DEVICE" --flavor dev -t lib/main_dev.dart "$@"
