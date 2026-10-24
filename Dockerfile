# Zero Ping Heroes website: Apache + mod_php runtime for WordPress.
# WordPress itself is NOT in the image; it lives in the bind-mounted ./www and
# is updated with wp-cli (see README).
#
# PHP_VERSION is the PHP minor line. The official php images are rebuilt for
# every PHP patch release, so rebuilding this image with --pull picks up
# security fixes. Nothing rebuilds it automatically: do it when PHP releases. Debian release pinned for reproducibility.
ARG PHP_VERSION=8.5
FROM php:${PHP_VERSION}-apache-trixie

# Runtime packages: ghostscript (PDF previews), HEIF/AVIF encoders, msmtp (mail)
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ghostscript \
        libheif-plugin-aomenc \
        libheif-plugin-x265 \
        msmtp \
    ; \
    rm -rf /var/lib/apt/lists/*

# PHP extensions WordPress uses. This mirrors the official wordpress image's
# recipe: build deps are removed afterwards, only the runtime libs are kept.
# https://make.wordpress.org/hosting/handbook/server-environment/#php-extensions
RUN set -eux; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libavif-dev \
        libfreetype6-dev \
        libicu-dev \
        libjpeg-dev \
        libmagickwand-dev \
        libpng-dev \
        libwebp-dev \
        libzip-dev \
    ; \
    docker-php-ext-configure gd --with-avif --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j "$(nproc)" bcmath exif gd intl mysqli zip; \
    pecl install imagick-3.8.1; \
    docker-php-ext-enable imagick; \
    rm -rf /tmp/pear; \
    extDir="$(php -r 'echo ini_get("extension_dir");')"; \
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$extDir"/*.so \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u | xargs -rt apt-mark manual; \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*; \
    ! { ldd "$extDir"/*.so | grep 'not found'; }; \
    err="$(php --version 3>&1 1>&2 2>&3)"; [ -z "$err" ]

# wp-cli, for core/plugin/theme updates without exposing the admin UI
# https://github.com/wp-cli/wp-cli/releases
ARG WP_CLI_VERSION=2.12.0
RUN set -eux; \
    curl -fsSL -o /usr/local/bin/wp "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"; \
    chmod +x /usr/local/bin/wp; \
    wp --allow-root --version

# Recommended opcache and error-logging settings (as in the official image).
# Security hardening lives in zz-security.ini so it loads last and wins over
# the bind-mounted conf.ini.
RUN set -eux; \
    { \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=4000'; \
        echo 'opcache.revalidate_freq=2'; \
    } > "$PHP_INI_DIR/conf.d/opcache-recommended.ini"; \
    { \
        echo 'display_errors = Off'; \
        echo 'display_startup_errors = Off'; \
        echo 'log_errors = On'; \
        echo 'error_log = /dev/stderr'; \
        echo 'html_errors = Off'; \
    } > "$PHP_INI_DIR/conf.d/error-logging.ini"; \
    { \
        echo '; Mitigation for CVE-2026-115560 (session upload progress), no fixed release yet.'; \
        echo '; https://www.php.net/archive/2026.php  - remove once a fixed PHP release ships.'; \
        echo 'session.upload_progress.enabled = 0'; \
        echo 'expose_php = Off'; \
    } > "$PHP_INI_DIR/conf.d/zz-security.ini"

# Apache: rewrite for permalinks, expires for caching, remoteip so WordPress
# and logs see real client IPs behind Nginx Proxy Manager (Docker networks).
RUN set -eux; \
    a2enmod rewrite expires remoteip; \
    { \
        echo 'RemoteIPHeader X-Forwarded-For'; \
        echo 'RemoteIPInternalProxy 10.0.0.0/8'; \
        echo 'RemoteIPInternalProxy 172.16.0.0/12'; \
        echo 'RemoteIPInternalProxy 192.168.0.0/16'; \
    } > /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    find /etc/apache2 -type f -name '*.conf' -exec sed -ri 's/([[:space:]]*LogFormat[[:space:]]+"[^"]*)%h([^"]*")/\1%a\2/g' '{}' +; \
    { echo 'ServerTokens Prod'; echo 'ServerSignature Off'; } > /etc/apache2/conf-available/zz-security.conf; \
    a2enconf zz-security

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS -o /dev/null http://localhost/wp-includes/images/blank.gif || exit 1
