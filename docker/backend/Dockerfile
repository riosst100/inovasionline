FROM php:8.3-cli

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    curl \
    libpq-dev \
    libzip-dev \
    libicu-dev \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    postgresql-client \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql \
        pgsql \
        gd \
        zip \
        intl \
        bcmath \
        pcntl \
        exif \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY entrypoint.sh /usr/local/bin/backend-entrypoint
RUN chmod +x /usr/local/bin/backend-entrypoint

ENV COMPOSER_HOME=/tmp/composer \
    HOME=/tmp \
    PHP_CLI_SERVER_WORKERS=4

WORKDIR /app
EXPOSE 8000 8080
