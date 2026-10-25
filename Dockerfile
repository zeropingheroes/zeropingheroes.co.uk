# Zero Ping Heroes website: the official WordPress image (Apache + PHP 8.5),
# plus msmtp, wp-cli and some hardening.
#
# The official image maintains the PHP extensions, opcache, error logging and
# Apache remoteip config, and is rebuilt upstream for every PHP release.
# Rebuild this image with --pull to pick those up.
#
# WordPress itself comes from the bind-mounted ./www (/var/www/html), NOT the
# copy bundled in the base image. The official entrypoint only copies its
# bundled WordPress in when /var/www/html has neither index.php nor
# wp-includes/version.php, and only writes wp-config.php when that file is
# missing AND WORDPRESS_* env vars are set. With the existing www/ it does neither.
ARG PHP_VERSION=8.5
FROM wordpress:php${PHP_VERSION}-apache

# msmtp: php.ini sets sendmail_path to it; msmtprc is bind-mounted
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends msmtp; \
    rm -rf /var/lib/apt/lists/*

# wp-cli, for core/plugin/theme updates without the admin UI
# https://github.com/wp-cli/wp-cli/releases
# The SHA-512 is pinned here, not fetched at build time, so a tampered release
# asset fails the build. The value matches the upstream release's .phar.sha512
# and the hash pinned in the official wordpress:cli image (docker-library/wordpress).
# When bumping the version, take the new hash from the release's
# wp-cli-<version>.phar.sha512 and cross-check it against the official image.
ARG WP_CLI_VERSION=2.12.0
ARG WP_CLI_SHA512=be928f6b8ca1e8dfb9d2f4b75a13aa4aee0896f8a9a0a1c45cd5d2c98605e6172e6d014dda2e27f88c98befc16c040cbb2bd1bfa121510ea5cdf5f6a30fe8832
RUN set -eux; \
    curl -fsSL -o /tmp/wp-cli.phar "https://github.com/wp-cli/wp-cli/releases/download/v${WP_CLI_VERSION}/wp-cli-${WP_CLI_VERSION}.phar"; \
    echo "${WP_CLI_SHA512} */tmp/wp-cli.phar" | sha512sum -c -; \
    install -m 0755 /tmp/wp-cli.phar /usr/local/bin/wp; \
    rm /tmp/wp-cli.phar; \
    wp --allow-root --version

# Hardening. zz-* loads last, so it wins over the bind-mounted conf.ini.
RUN set -eux; \
    { \
        echo '; Mitigation for CVE-2026-115560 (session upload progress), no fixed release yet.'; \
        echo '; https://www.php.net/archive/2026.php  - remove once a fixed PHP release ships.'; \
        echo 'session.upload_progress.enabled = 0'; \
        echo 'expose_php = Off'; \
    } > "$PHP_INI_DIR/conf.d/zz-security.ini"; \
    { echo 'ServerTokens Prod'; echo 'ServerSignature Off'; } > /etc/apache2/conf-available/zz-security.conf; \
    a2enconf zz-security

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS -o /dev/null http://localhost/wp-includes/images/blank.gif || exit 1
