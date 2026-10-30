#!/usr/bin/env bash
# Production deploy for api.inovasionline.com (backend), admin.inovasionline.com (frontend-admin)
# and inovasionline.com (frontend).
# Run on the VPS from the repo root after the code has been updated (see .github/workflows/deploy.yml).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PHP_FPM_SERVICE="${PHP_FPM_SERVICE:-php8.3-fpm}"
PM2_APP_NAME="${PM2_APP_NAME:-inovasionline-admin}"
ADMIN_PORT="${ADMIN_PORT:-3040}"
WEB_PM2_APP_NAME="${WEB_PM2_APP_NAME:-inovasionline-web}"
WEB_PORT="${WEB_PORT:-3050}"

echo "==> Backend"
cd "$ROOT/backend"
composer install --no-dev --optimize-autoloader --no-interaction --no-progress
php artisan migrate --force
php artisan optimize:clear
php artisan optimize
# Applies config/scout.php index settings once Meilisearch is set up (scripts/setup-meilisearch.sh).
if grep -q '^SCOUT_DRIVER=meilisearch' .env; then
  php artisan scout:sync-index-settings
fi
chown -R www-data:www-data storage bootstrap/cache
php artisan queue:restart
systemctl reload "$PHP_FPM_SERVICE"

# Install deps in $1 and (re)start it under pm2 as $2 on 127.0.0.1:$3.
# With PREBUILT_DIR set, the .next build comes from CI ($PREBUILT_DIR/$4.tgz) instead of being built here;
# no bundle there means the app didn't change, so it is skipped.
deploy_next_app() {
  local dir="$1" name="$2" port="$3" bundle="$4"
  if [ -n "${PREBUILT_DIR:-}" ] && [ ! -f "$PREBUILT_DIR/$bundle.tgz" ]; then
    echo "==> $dir unchanged, skipping"
    return
  fi
  cd "$ROOT/$dir"
  export NEXT_TELEMETRY_DISABLED=1
  # Incremental install (keeps node_modules); devDependencies stay because next.config.ts needs typescript.
  npm install --no-audit --no-fund
  if [ -n "${PREBUILT_DIR:-}" ] && [ -f "$PREBUILT_DIR/$bundle.tgz" ]; then
    rm -rf .next
    tar -xzf "$PREBUILT_DIR/$bundle.tgz"
    rm -f "$PREBUILT_DIR/$bundle.tgz"
  else
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
  fi
  if pm2 describe "$name" >/dev/null 2>&1; then
    pm2 restart "$name" --update-env
  else
    pm2 start npm --name "$name" -- start -- -p "$port" -H 127.0.0.1
  fi
}

echo "==> Frontend admin"
deploy_next_app frontend-admin "$PM2_APP_NAME" "$ADMIN_PORT" frontend-admin-next

echo "==> Frontend (inovasionline.com)"
NEXT_PUBLIC_SITE_URL=https://inovasionline.com \
NEXT_PUBLIC_API_URL=https://api.inovasionline.com/api/v1 \
  deploy_next_app frontend "$WEB_PM2_APP_NAME" "$WEB_PORT" frontend-next

pm2 save

echo "==> Deploy finished: $(git -C "$ROOT" rev-parse --short HEAD)"
