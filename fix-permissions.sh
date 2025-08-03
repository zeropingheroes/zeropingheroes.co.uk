#!/bin/bash

cd ./www

find . -type d -exec chmod 755 {} \;
find . -type f -exec chmod 644 {} \;

chmod -R 775 ./wp-content/uploads
chmod 440 ./wp-config.php
