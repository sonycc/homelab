#!/bin/bash
# LF line endings required; see .gitattributes.
#
# Job queue plus images/ archiving. No cron: Debian's cron scrubs the
# environment, so IMAGES_* and PG* would arrive empty.
set -euo pipefail

IP=/var/www/html
IMAGES="$IP/images"
BACKUP_DIR=/backups

# Root only long enough to own the backup directory.
# MediaWiki writes thumbnails into images/, and root-owned files there are ones
# Apache cannot replace.
if [ "$(id -u)" = 0 ]; then
  mkdir -p "$BACKUP_DIR"
  chown www-data:www-data "$BACKUP_DIR"
  exec runuser -u www-data -- "$0" "$@"
fi

shopt -s nullglob

notify() {
  echo "FAILED - $1" >&2
  [ -n "${DISCORD_WEBHOOK_URL:-}" ] || return 0
  curl -fsS -X POST -H 'Content-Type: application/json' \
    -d "{\"content\":\"**wiki images backup failed** - $1\"}" \
    "$DISCORD_WEBHOOK_URL" >/dev/null 2>&1 || true
}

manifest() {
  find "$IMAGES" -type f -printf '%P %s %T@\n' | sort | sha256sum | cut -d' ' -f1
}

# Archives only when the directory changed, so retention holds the last IMAGES_KEEP
# distinct states rather than IMAGES_KEEP copies of the same files.
# Called as an if condition, where set -e does not apply, so each step checks its own status.
archive() {
  local current stamp partial
  current="$(manifest)" || return 1

  local manifests=( "$BACKUP_DIR"/images_*.manifest )
  if [ ${#manifests[@]} -gt 0 ] && [ "$current" = "$(cat "${manifests[-1]}")" ]; then
    return 0
  fi

  stamp="$(date +%Y-%m-%d_%H-%M-%S)"
  # Staged under a name the retention glob does not match, so a half-written
  # archive is never counted or pruned as a real one.
  partial="$BACKUP_DIR/.partial_$stamp.tar.gz"

  if ! tar czf "$partial" -C "$IP" images || ! tar tzf "$partial" >/dev/null; then
    rm -f "$partial"
    return 1
  fi

  mv "$partial" "$BACKUP_DIR/images_$stamp.tar.gz" || return 1
  printf '%s\n' "$current" > "$BACKUP_DIR/images_$stamp.manifest" || return 1

  local archives=( "$BACKUP_DIR"/images_*.tar.gz )
  local excess=$(( ${#archives[@]} - IMAGES_KEEP ))
  if [ "$excess" -gt 0 ]; then
    local old
    for old in "${archives[@]:0:$excess}"; do
      rm -f "$old" "${old%.tar.gz}.manifest"
    done
  fi
}

last_check=0

while true; do
  php "$IP/maintenance/run.php" runJobs --maxjobs "$JOB_BATCH" --quiet || true

  now="$(date +%s)"
  if [ $(( now - last_check )) -ge "$IMAGES_CHECK_INTERVAL" ]; then
    if archive; then
      touch "$BACKUP_DIR/.last-success"
    else
      notify "could not write an images archive"
    fi
    last_check="$now"
  fi

  sleep 60
done
