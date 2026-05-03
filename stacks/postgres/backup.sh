#!/bin/sh

set -e

TYPE=$1

if [ -z "$TYPE" ]; then
  echo "Usage: backup.sh [hourly|daily|weekly|monthly]"
  exit 1
fi

# Map env vars dynamically
case "$TYPE" in
  hourly)
    KEEP=$BACKUP_HOURLY_KEEP
    ;;
  daily)
    KEEP=$BACKUP_DAILY_KEEP
    ;;
  weekly)
    KEEP=$BACKUP_WEEKLY_KEEP
    ;;
  monthly)
    KEEP=$BACKUP_MONTHLY_KEEP
    ;;
  *)
    echo "Invalid backup type: $TYPE"
    exit 1
    ;;
esac

BACKUP_DIR_FINAL="$BACKUP_DIR/$TYPE"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILE="$BACKUP_DIR_FINAL/db_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR_FINAL"

echo "Running $TYPE backup..."

export PGPASSWORD="$POSTGRES_PASSWORD"

pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "$FILE"

echo "Saved: $FILE"

echo "Retention: keeping last $KEEP"

ls -1t "$BACKUP_DIR_FINAL"/*.sql.gz 2>/dev/null | tail -n +$(($KEEP + 1)) | xargs -r rm --

echo "Done"