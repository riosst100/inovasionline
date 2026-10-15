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

RUN printf 'upload_max_filesize=10M\npost_max_size=12M\n' > /usr/local/etc/php/conf.d/uploads.ini

COPY entrypoint.sh /usr/local/bin/backend-entrypoint
RUN sed -i 's/\r$//' /usr/local/bin/backend-entrypoint && chmod +x /usr/local/bin/backend-entrypoint

ENV COMPOSER_HOME=/tmp/composer \
    HOME=/tmp \
    PHP_CLI_SERVER_WORKERS=4

WORKDIR /app
EXPOSE 8000 8080
