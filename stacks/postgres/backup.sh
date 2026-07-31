#!/bin/sh
# Bind-mounted into an Alpine container, so LF line endings are required: with CRLF
# the kernel reads the shebang as "/bin/sh\r" and reports "not found". Pinned by the
# repo-root .gitattributes.

set -eu
# Without this, `pg_dumpall | gzip` reports only gzip's status and a failed dump
# still produces a well-formed empty archive.
set -o pipefail

TYPE="${1:-}"

case "$TYPE" in
  hourly)  KEEP="${BACKUP_HOURLY_KEEP:-0}"  ;;
  daily)   KEEP="${BACKUP_DAILY_KEEP:-0}"   ;;
  weekly)  KEEP="${BACKUP_WEEKLY_KEEP:-0}"  ;;
  monthly) KEEP="${BACKUP_MONTHLY_KEEP:-0}" ;;
  "")      echo "Usage: backup.sh [hourly|daily|weekly|monthly]" >&2 ; exit 1 ;;
  *)       echo "Invalid backup type: $TYPE" >&2 ; exit 1 ;;
esac

DEST="$BACKUP_DIR/$TYPE"
FILE="$DEST/db_$(date +%Y-%m-%d_%H-%M-%S).sql.gz"

# Built under a name the retention glob (db_*.sql.gz) does not match, so a dump
# that dies half-way can never be mistaken for a backup or rotate a good one away.
TMP="$DEST/.in-progress-$$.sql.gz"

mkdir -p "$DEST"
trap 'rm -f "$TMP"' EXIT

echo "Running $TYPE backup..."

export PGPASSWORD="$POSTGRES_PASSWORD"

# Instance-wide: each service owns its own database and role, so the backup needs
# every database plus the role definitions — databases restored into an instance
# without their roles are unusable.
#
# -h is required: there is no postgres server in this container, so libpq has no
# unix socket to fall back on.
pg_dumpall -h "${PGHOST:-postgres}" -U "$POSTGRES_USER" | gzip > "$TMP"

# pipefail covers a failing pg_dumpall; these cover a dump that "succeeded" into a
# truncated or empty file.
gzip -t "$TMP"
[ -s "$TMP" ]

mv "$TMP" "$FILE"
echo "Saved: $FILE ($(du -h "$FILE" | cut -f1))"

# Read by the container healthcheck; a stale timestamp surfaces "backups stopped".
touch "$BACKUP_DIR/.last-success"

echo "Retention: keeping last $KEEP"
ls -1t "$DEST"/db_*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | xargs -r rm -f --

echo "Done"
