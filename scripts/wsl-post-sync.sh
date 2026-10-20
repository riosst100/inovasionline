#!/usr/bin/env bash
# Dijalankan di WSL setelah tiap sync (wsl-sync.sh / wsl-watch.ps1). stdin = output `rsync -i`.
# Menerapkan perubahan ke container yang sedang jalan, supaya tidak perlu langkah manual:
#   - migrasi baru/berubah     -> php artisan migrate
#   - backend/composer.lock    -> composer install
#   - kode PHP backend         -> queue worker di-restart (worker memuat kode sekali saat start)
#   - queue/reverb terikat ke folder kosong -> container di-restart
# Usage: rsync -i ... | bash wsl-post-sync.sh <dest>
set -uo pipefail

DEST="$1"
READY_MARKER=storage/framework/.inovasionline-ready

# Baris rsync -i: "<flags> <path>", termasuk "*deleting <path>". Folder (akhiran /) diabaikan.
changes=$(awk '{ $1 = ""; sub(/^ +/, ""); print }' | grep -v '/$' || true)
[ -n "$changes" ] || exit 0

has() { printf '%s\n' "$changes" | grep -qE "$1"; }
say() { echo "  -> $*"; }

echo "  $(printf '%s\n' "$changes" | wc -l) file berubah"

cd "$DEST" || exit 0

if has '^(docker/|docker-compose\.yml$)'; then
  say "konfigurasi Docker berubah: jalankan '.\\sync.ps1 up' untuk rebuild"
fi

if [ -z "$(docker compose ps --status running -q backend 2>/dev/null)" ]; then
  say "container backend tidak jalan, langkah backend dilewati"
  exit 0
fi

backend() { docker compose exec -T backend "$@"; }

# Container yang start sebelum folder backend ada di WSL terikat ke folder kosong
# dan menunggu selamanya; restart membuatnya memasang folder yang benar.
for svc in queue reverb; do
  if [ -n "$(docker compose ps --status running -q "$svc" 2>/dev/null)" ] &&
     ! docker compose exec -T "$svc" test -f artisan 2>/dev/null; then
    say "$svc tidak melihat kode backend, restart"
    docker compose restart "$svc" >/dev/null
  fi
done

# Backend yang baru (re)start masih menjalankan setup di entrypoint (composer, migrate).
for _ in $(seq 60); do
  backend test -f "$READY_MARKER" 2>/dev/null && break
  sleep 2
done

if has '^backend/composer\.lock$'; then
  say "composer install"
  backend composer install --no-interaction --prefer-dist || say "composer install GAGAL"
fi

if has '^backend/database/migrations/'; then
  say "php artisan migrate"
  backend php artisan migrate --force || say "migrate GAGAL, cek output di atas"
fi

if has '^backend/(app|bootstrap|config|database|routes)/.*\.php$|^backend/composer\.lock$'; then
  # Worker selesai job yang sedang jalan, lalu Docker (restart: unless-stopped) menyalakannya lagi.
  backend php artisan queue:restart >/dev/null && say "queue worker di-restart"
fi
