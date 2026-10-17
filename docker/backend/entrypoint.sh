#!/bin/sh
set -e

cd /app
READY_MARKER=storage/framework/.inovasionline-ready

wait_for_api() {
    echo "Waiting for backend container to complete initial setup..."
    until [ -f "$READY_MARKER" ]; do sleep 2; done
}

case "$1" in
    serve)
        # storage/ subfolders are not synced to WSL (scripts/wsl-sync.sh), so recreate them.
        mkdir -p storage/framework/cache/data storage/framework/sessions storage/framework/views \
            storage/logs storage/app/public bootstrap/cache
        rm -f "$READY_MARKER"

        [ -f .env ] || cp .env.example .env

        if [ ! -f vendor/autoload.php ]; then
            echo "Installing composer dependencies..."
            composer install --no-interaction --prefer-dist
        fi

        echo "Waiting for PostgreSQL at ${DB_HOST:-db}:${DB_PORT:-5432}..."
        until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USERNAME:-postgres}" >/dev/null 2>&1; do
            sleep 1
        done
        echo "PostgreSQL is ready!"

        if ! grep -q '^APP_KEY=base64' .env; then
            echo "Generating application key..."
            php artisan key:generate --force
        fi

        if [ ! -L public/storage ] && [ ! -d public/storage ]; then
            php artisan storage:link || true
        fi

        echo "Running database migrations..."
        php artisan migrate --force

        # Seed if users table is empty
        USER_COUNT=$(php artisan tinker --execute="echo \App\Models\User::count();" 2>/dev/null | tail -n 1 || echo "0")
        if [ "$USER_COUNT" = "0" ]; then
            echo "Fresh database detected. Running seeders..."
            php artisan db:seed --force || echo "Seed warning (continuing)..."
        fi

        touch "$READY_MARKER"
        echo "Starting Laravel server on 0.0.0.0:8000..."
        exec php artisan serve --host=0.0.0.0 --port=8000 --no-reload
        ;;
    queue)
        wait_for_api
        echo "Starting queue worker..."
        exec php artisan queue:work --tries=3 --timeout=1800 --sleep=3
        ;;
    reverb)
        wait_for_api
        echo "Starting Reverb websocket server on port 8080..."
        exec php artisan reverb:start --host=0.0.0.0 --port=8080
        ;;
    scheduler)
        wait_for_api
        echo "Starting Laravel scheduler..."
        exec php artisan schedule:work
        ;;
    *)
        exec "$@"
        ;;
esac
