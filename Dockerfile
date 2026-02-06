FROM php:8.3-apache

# System deps for PHP extensions + tools Composer uses
RUN apt-get update && apt-get install -y \
    git unzip \
    postgresql-client \
    libzip-dev \
    libpq-dev \
    libicu-dev \
    libpng-dev libjpeg-dev libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*


# PHP extensions (Drupal commonly needs these)
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    pdo pdo_pgsql \
    zip \
    intl \
    gd \
    mbstring \
    opcache

# Apache settings
RUN a2enmod rewrite headers

# Set Apache docroot to /web (Drupal recommended-project)
ENV APACHE_DOCUMENT_ROOT=/var/www/html/web
RUN sed -ri 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf \
    && sed -ri 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

RUN composer install --no-dev --optimize-autoloader

COPY scripts/start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 80
CMD ["/start.sh"]
