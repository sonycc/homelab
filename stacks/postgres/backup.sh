#!/bin/sh

set -e

BACKUP_DIR="/backups"
TIMESTAMP=$(date +%F_%H-%M)
FILE="$BACKUP_DIR/appdb_$TIMESTAMP.sql"

echo "Starting backup: $FILE"

pg_dump -h postgres \
  -U "$POSTGRES_USER" \
  "$POSTGRES_DB" > "$FILE"

echo "Backup completed: $FILE"