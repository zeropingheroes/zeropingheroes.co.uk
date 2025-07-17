#!/bin/bash

set -e

source .env

DATE=$(date +"%Y-%m-%d")
BACKUP_FILENAME_WEBROOT="wordpress-webroot-$DATE"
BACKUP_FILENAME_DATABASE="wordpress-database-$DATE"

echo "Creating temporary directory $BACKUP_TEMP_DIR"
mkdir -p "$BACKUP_TEMP_DIR"

echo "Dumping database to temporary SQL file"
docker exec "$BACKUP_CONTAINER_NAME_MYSQL" sh -c 'exec mysqldump "$WORDPRESS_DB_NAME" -uroot -p"$MYSQL_ROOT_PASSWORD"' >  "$BACKUP_TEMP_DIR/$BACKUP_FILENAME_DATABASE.sql"

echo "Compressing database temporary SQL file"
tar zcf "$BACKUP_TEMP_DIR/$BACKUP_FILENAME_DATABASE.tar.gz" "$BACKUP_TEMP_DIR/$BACKUP_FILENAME_DATABASE.sql"

echo "Removing temporary database SQL file"
rm "$BACKUP_TEMP_DIR/$BACKUP_FILENAME_DATABASE.sql"

echo "Compressing web root files"
docker run --rm --volumes-from "$BACKUP_CONTAINER_NAME_WORDPRESS" -v "$BACKUP_TEMP_DIR":/backup busybox tar zcf "/backup/$BACKUP_FILENAME_WEBROOT.tar.gz" "/var/www/html"
