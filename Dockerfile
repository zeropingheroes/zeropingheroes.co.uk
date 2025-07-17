FROM wordpress:6.8.2-apache

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends msmtp; \
    rm -rf /var/lib/apt/lists/*
