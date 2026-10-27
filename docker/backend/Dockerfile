FROM php:8.3-cli-bookworm

COPY --from=mlocati/php-extension-installer:latest /usr/bin/install-php-extensions /usr/local/bin/
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/* \
    && install-php-extensions pdo_pgsql pgsql gd zip intl bcmath pcntl exif redis

# 52M/56M: videos are validated up to 50 MB (see CreatePostRequest).
RUN printf 'upload_max_filesize=52M\npost_max_size=56M\n' > /usr/local/etc/php/conf.d/uploads.ini

# OPcache: the CLI server (artisan serve), queue and reverb workers otherwise re-parse every PHP file
# per request/job. Timestamps stay validated (every 2s) because ./backend is a bind-mounted, edited tree.
RUN printf 'opcache.enable=1\nopcache.enable_cli=1\nopcache.memory_consumption=192\nopcache.interned_strings_buffer=16\nopcache.max_accelerated_files=20000\nopcache.validate_timestamps=1\nopcache.revalidate_freq=2\n' > /usr/local/etc/php/conf.d/opcache.ini

COPY entrypoint.sh /usr/local/bin/backend-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/backend-entrypoint && chmod +x /usr/local/bin/backend-entrypoint

ENV COMPOSER_HOME=/tmp/composer \
    HOME=/tmp \
    PHP_CLI_SERVER_WORKERS=4

WORKDIR /app
EXPOSE 8000 8080
