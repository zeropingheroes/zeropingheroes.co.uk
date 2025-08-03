FROM php:8.3-apache

RUN set -eux ; \
    a2enmod rewrite ; \
    docker-php-ext-install mysqli ; \
    docker-php-ext-enable mysqli ; \
    apt update ; apt install -y zlib1g-dev libpng-dev ; rm -rf /var/lib/apt/lists/* ; \
    docker-php-ext-install gd ; \
    docker-php-ext-enable gd ; \
    docker-php-ext-install exif ; \
    docker-php-ext-enable exif ; \
    apt-get update ; apt-get install -y libmagickwand-dev --no-install-recommends ; rm -rf /var/lib/apt/lists/* ; \
    pecl install imagick ; \
    docker-php-ext-enable imagick ; \
    apt-get update ; apt-get install -y libzip-dev --no-install-recommends ; rm -rf /var/lib/apt/lists/* ; \
    docker-php-ext-install zip ; \
    docker-php-ext-enable zip ; \
    docker-php-ext-install intl ; \
    docker-php-ext-enable intl ; \
    apt-get update; \
    apt-get install -y --no-install-recommends msmtp; \
    rm -rf /var/lib/apt/lists/*
