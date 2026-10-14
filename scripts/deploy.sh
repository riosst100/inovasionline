#!/usr/bin/env bash
# Production deploy for api.inovasionline.com (backend) and admin.inovasionline.com (frontend-admin).
# Run on the VPS from the repo root after the code has been updated (see .github/workflows/deploy.yml).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-php8.3-fpm}"
PM2_APP_NAME="${PM2_APP_NAME:-inovasionline-admin}"
ADMIN_PORT="${ADMIN_PORT:-3040}"

echo "==> Backend"
cd "$ROOT/backend"
composer install --no-dev --optimize-autoloader --no-interaction --no-progress
php artisan migrate --force
php artisan optimize:clear
php artisan optimize
chown -R www-data:www-data storage bootstrap/cache
php artisan queue:restart
systemctl reload "$PHP_FPM_SERVICE"

echo "==> Frontend admin"
cd "$ROOT/frontend-admin"
export NEXT_TELEMETRY_DISABLED=1
npm ci --no-audit --no-fund
# Keep the last good build so a failed build doesn't leave the running app without one.
rm -rf .next.prev
[ -d .next ] && cp -a .next .next.prev
if ! npm run build; then
  echo "!! Build failed, restoring previous .next" >&2
  rm -rf .next
  [ -d .next.prev ] && mv .next.prev .next
  exit 1
fi
rm -rf .next.prev
if pm2 describe "$PM2_APP_NAME" >/dev/null 2>&1; then
  pm2 restart "$PM2_APP_NAME" --update-env
else
  pm2 start npm --name "$PM2_APP_NAME" -- start -- -p "$ADMIN_PORT" -H 127.0.0.1
fi
pm2 save

echo "==> Deploy finished: $(git -C "$ROOT" rev-parse --short HEAD)"
