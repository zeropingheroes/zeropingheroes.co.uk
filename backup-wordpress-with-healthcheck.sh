#!/bin/bash

readarray HEALTHCHECK_IDS < backup.healthchecks

for HEALTHCHECK_ID in "${HEALTHCHECK_IDS[@]}"; do
    # Remove trailing new line
    HEALTHCHECK_ID=${HEALTHCHECK_ID%$'\n'}
    curl -fsS --retry 3 -o /dev/null "https://hc-ping.com/$HEALTHCHECK_ID/start"
done

source .env

BACKUP_SCRIPT_OUTPUT=$("./backup-wordpress.sh" 2>&1)

BACKUP_SCRIPT_EXIT_CODE=$?

for HEALTHCHECK_ID in "${HEALTHCHECK_IDS[@]}"; do
    # Remove trailing new line
    HEALTHCHECK_ID=${HEALTHCHECK_ID%$'\n'}
    curl -fsS --retry 3 -o /dev/null --data-raw "$BACKUP_SCRIPT_OUTPUT" "https://hc-ping.com/$HEALTHCHECK_ID/$BACKUP_SCRIPT_EXIT_CODE"
done

echo "$BACKUP_SCRIPT_OUTPUT"
