#!/usr/bin/env bash
# Local (Docker Compose) deployment script for inovasionline
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"
log() { printf '\n==> %s\n' "$*"; }
dc() { docker compose "$@"; }

log "Docker: build images and start containers"
dc up -d --build

log "Backend: wait for setup to finish"
until dc exec -T backend test -f storage/framework/.inovasionline-ready; do sleep 2; done

log "Backend: clear caches"
dc exec -T backend php artisan optimize:clear

log "Backend: warm config/route/view caches"
dc exec -T backend php artisan optimize || echo "optimize skipped (e.g. a route closure blocks route:cache)"

log "Backend: restart background services"
dc restart reverb queue

log "Local deploy finished!"
dc ps
