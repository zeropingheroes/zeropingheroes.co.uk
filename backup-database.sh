#!/bin/bash

source .env

docker exec mysql sh -c 'exec mysqldump "$WORDPRESS_DB_NAME" -uroot -p"$MYSQL_ROOT_PASSWORD"' > ./wordpress.sql
