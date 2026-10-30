#!/usr/bin/env bash
# Pasang Meilisearch di VPS production dan aktifkan pencarian produk lewat Laravel Scout.
# Jalankan SEKALI sebagai root dari root repo:  sudo bash scripts/setup-meilisearch.sh
# Aman dijalankan ulang: master key yang sudah ada dipakai lagi, binary tidak diunduh ulang.
#
# Hasil:
#   - binary /usr/local/bin/meilisearch, data di /var/lib/meilisearch, config /etc/meilisearch.toml
#   - service systemd "meilisearch", hanya listen di 127.0.0.1:7700 (tidak terbuka ke internet)
#   - backend/.env: SCOUT_DRIVER=meilisearch + host + key, lalu index produk diisi
#
# Versi harus sama dengan image di docker-compose.yml supaya hasil dev = production.
set -euo pipefail

MEILI_VERSION="${MEILI_VERSION:-1.13.3}"
MEILI_ADDR="127.0.0.1:7700"
MEILI_USER=meilisearch
DATA_DIR=/var/lib/meilisearch
CONFIG=/etc/meilisearch.toml
BIN=/usr/local/bin/meilisearch
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-php8.3-fpm}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/backend/.env"

[ "$(id -u)" -eq 0 ] || { echo "Jalankan sebagai root: sudo bash $0" >&2; exit 1; }
[ -f "$ENV_FILE" ] || { echo "$ENV_FILE tidak ditemukan" >&2; exit 1; }

echo "==> Binary Meilisearch v$MEILI_VERSION"
installed="$("$BIN" --version 2>/dev/null | awk '{print $2}' || true)"
if [ "$installed" = "$MEILI_VERSION" ]; then
  echo "    sudah terpasang"
else
  # Data dari versi lain tidak selalu bisa dibaca versi baru; upgrade harus lewat dump.
  if [ -n "$installed" ] && [ -d "$DATA_DIR/data.ms" ]; then
    echo "!! Terpasang v$installed dengan data di $DATA_DIR. Upgrade perlu dump dulu:" >&2
    echo "   https://www.meilisearch.com/docs/learn/update_and_migration/updating" >&2
    echo "   Atau, karena index bisa dibangun ulang dari DB: hapus $DATA_DIR/data.ms lalu jalankan ulang script ini." >&2
    exit 1
  fi
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *) echo "Arsitektur $(uname -m) tidak didukung" >&2; exit 1 ;;
  esac
  tmp="$(mktemp)"
  curl -fsSL -o "$tmp" \
    "https://github.com/meilisearch/meilisearch/releases/download/v$MEILI_VERSION/meilisearch-linux-$arch"
  install -m 0755 "$tmp" "$BIN"
  rm -f "$tmp"
  "$BIN" --version
fi

echo "==> User & folder data"
id "$MEILI_USER" >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin "$MEILI_USER"
mkdir -p "$DATA_DIR/dumps" "$DATA_DIR/snapshots"
chown -R "$MEILI_USER:$MEILI_USER" "$DATA_DIR"

echo "==> Config $CONFIG"
master_key="$(sed -n 's/^master_key *= *"\(.*\)"$/\1/p' "$CONFIG" 2>/dev/null || true)"
if [ -z "$master_key" ]; then
  master_key="$(openssl rand -hex 32)"
  echo "    master key baru dibuat"
else
  echo "    master key lama dipakai"
fi
cat >"$CONFIG" <<CONF
env = "production"
master_key = "$master_key"
http_addr = "$MEILI_ADDR"
db_path = "$DATA_DIR/data.ms"
dump_dir = "$DATA_DIR/dumps"
snapshot_dir = "$DATA_DIR/snapshots"
no_analytics = true
CONF
chown root:"$MEILI_USER" "$CONFIG"
chmod 0640 "$CONFIG"

echo "==> Service systemd"
cat >/etc/systemd/system/meilisearch.service <<UNIT
[Unit]
Description=Meilisearch
After=network.target

[Service]
Type=simple
User=$MEILI_USER
Group=$MEILI_USER
WorkingDirectory=$DATA_DIR
ExecStart=$BIN --config-file-path $CONFIG
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable meilisearch >/dev/null
systemctl restart meilisearch

for _ in $(seq 30); do
  curl -sf "http://$MEILI_ADDR/health" >/dev/null && break
  sleep 1
done
curl -sf "http://$MEILI_ADDR/health" >/dev/null || {
  echo "!! Meilisearch tidak merespons. Cek: journalctl -u meilisearch -n 50" >&2
  exit 1
}
echo "    jalan di http://$MEILI_ADDR"

echo "==> backend/.env"
set_env() {
  if grep -q "^$1=" "$ENV_FILE"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$1" "$2" >>"$ENV_FILE"
  fi
}
set_env SCOUT_DRIVER meilisearch
set_env MEILISEARCH_HOST "http://$MEILI_ADDR"
set_env MEILISEARCH_KEY "$master_key"

echo "==> Index produk"
cd "$ROOT/backend"
php artisan config:cache
php artisan scout:sync-index-settings
# SCOUT_QUEUE aktif: import dikirim ke queue, worker yang mengisi index.
php artisan scout:import "App\Models\Product"
php artisan queue:restart
systemctl reload "$PHP_FPM_SERVICE"

echo "==> Selesai. Cek jumlah dokumen (setelah queue memproses):"
echo "    curl -s -H 'Authorization: Bearer <MEILISEARCH_KEY di backend/.env>' http://$MEILI_ADDR/indexes/products/stats"
