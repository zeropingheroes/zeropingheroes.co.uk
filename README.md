# Zero Ping Heroes Website

Website configuration for https://www.zeropingheroes.co.uk/

## Image

`Dockerfile` extends the official `wordpress:php8.5-apache` image with msmtp, wp-cli and some
hardening. The official image maintains the PHP extensions, opcache, error logging and remote IP
handling.

WordPress itself runs from the bind-mounted `www/` directory, not the copy bundled in the base
image. The official entrypoint only installs its bundled copy when `www/` has neither `index.php`
nor `wp-includes/version.php`. It only writes `wp-config.php` when that file is missing **and**
`WORDPRESS_*` environment variables are set. **Don't add `WORDPRESS_*` variables to `.env`.**

The image is built locally on the server; it isn't published to a registry. The server's stack uses
this repo clone as its build context and tags the result `zph-website:php8.5`. The official image is
rebuilt upstream for every PHP release, so **rebuild when PHP ships a security fix**:

```bash
./dc zeropingheroes build --pull && ./dc zeropingheroes up -d    # from the server's stack repo
docker exec zph_wordpress php -v
```

To move to a new PHP minor version: change `PHP_VERSION` in the `Dockerfile` and the image tag, then
check WordPress compatibility first
(https://make.wordpress.org/core/handbook/references/php-compatibility-and-wordpress-versions/).

## Updating WordPress

The image includes wp-cli. Run these from the server's stack directory. `exec` runs as the
container's user (`1000:988`, which owns `www/`), so file ownership stays correct:

```bash
docker compose exec zph_wordpress wp core update
docker compose exec zph_wordpress wp core update-db
docker compose exec zph_wordpress wp plugin update --all
docker compose exec zph_wordpress wp theme update --all
docker compose exec zph_wordpress wp language core update
```

## Added on top of the official image

- `msmtp`, used by `sendmail_path` in `php.ini`
- wp-cli
- `session.upload_progress.enabled = 0`: mitigates CVE-2026-115560 until a fixed PHP release ships
- `expose_php = Off`, `ServerTokens Prod`, `ServerSignature Off`
- A healthcheck against a static file
