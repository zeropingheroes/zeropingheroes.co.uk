#!/bin/bash

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source .env

DATE=$(date +"%Y-%m-%d")
BACKUP_FILENAME_DATABASE="wordpress-database-$DATE"

echo "Creating temporary directory $BACKUP_TEMP_DIR"
mkdir -p "$BACKUP_TEMP_DIR"

echo "Changing directory to temporary directory"
cd "$BACKUP_TEMP_DIR"

echo "Dumping database to temporary SQL file"
docker exec "$BACKUP_CONTAINER_NAME_MYSQL" sh -c 'exec mysqldump "$MYSQL_DATABASE" -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$BACKUP_FILENAME_DATABASE.sql"

echo "Compressing database temporary SQL file"
tar zcf "$BACKUP_FILENAME_DATABASE.tar.gz" "$BACKUP_FILENAME_DATABASE.sql"

echo "Removing temporary database SQL file"
rm "$BACKUP_TEMP_DIR/$BACKUP_FILENAME_DATABASE.sql"

echo "Sending files to $BACKUP_DESTINATION"
rsync --archive --no-links "$BACKUP_TEMP_DIR/" "$SCRIPT_DIR/www" "$BACKUP_DESTINATION"

echo "Removing temporary directory $BACKUP_TEMP_DIR"
rm -rf "$BACKUP_TEMP_DIR"
