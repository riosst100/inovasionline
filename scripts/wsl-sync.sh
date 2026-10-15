#!/usr/bin/env bash
# Sync project dari Windows (D:\inovasionline) ke filesystem WSL lalu jalankan Docker di sana.
# Pakai dari PowerShell/Git Bash di Windows:
#   bash scripts/wsl-sync.sh            # sync sekali
#   bash scripts/wsl-sync.sh up         # sync + docker compose up -d
#   bash scripts/wsl-sync.sh watch      # sync terus-menerus (tiap 2 detik)
#   bash scripts/wsl-sync.sh down|logs|ps
# Edit hanya di Windows; folder tujuan WSL ditimpa tiap sync.
set -euo pipefail

DISTRO="${WSL_DISTRO:-Ubuntu-24.04}"
DEST="${WSL_DEST:-\$HOME/projects/inovasionline}"
SRC_WIN="$(cd "$(dirname "$0")/.." && pwd -W 2>/dev/null || pwd)"
SRC_WSL="$(wsl -d "$DISTRO" -- wslpath -a "$SRC_WIN" | tr -d '\r')"

case "$SRC_WSL" in /mnt/?*) ;; *) echo "wslpath gagal: '$SRC_WSL'" >&2; exit 1 ;; esac

wsh() { wsl -d "$DISTRO" -- bash -lc "$1"; }

sync_once() {
  wsh "mkdir -p $DEST && rsync -a --delete \
    --exclude='.git/' --exclude='node_modules/' --exclude='.next/' \
    --exclude='backend/vendor/' --exclude='backend/.env' \
    --exclude='backend/storage/logs/' --exclude='backend/storage/framework/' \
    --exclude='backend/storage/app/' --exclude='backend/public/storage' \
    --exclude='apps/' --exclude='.env' \
    '$SRC_WSL/' $DEST/"
}

[ -f "$SRC_WIN/.env" ] && wsh "cp -n '$SRC_WSL/.env' $DEST/.env 2>/dev/null || true"

case "${1:-sync}" in
  sync)  sync_once ;;
  up)    sync_once; wsh "cd $DEST && [ -f .env ] || cp .env.example .env; docker compose up -d --build && docker compose ps" ;;
  watch) powershell.exe -ExecutionPolicy Bypass -File "$(cygpath -w "$SRC_WIN/scripts/wsl-watch.ps1")" ;;
  down)  wsh "cd $DEST && docker compose down" ;;
  logs)  wsh "cd $DEST && docker compose logs -f --tail=100 ${2:-}" ;;
  ps)    wsh "cd $DEST && docker compose ps" ;;
  *) echo "usage: $0 [sync|up|watch|down|logs [svc]|ps]"; exit 1 ;;
esac
