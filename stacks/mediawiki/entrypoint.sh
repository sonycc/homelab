#!/bin/bash
# Config comes from MW_CONFIG_FILE, so $IP/LocalSettings.php never exists.
set -euo pipefail

IP=/var/www/html

# Schema-qualified so the check holds when MW_DB_USER and MW_DB_SCHEMA differ.
# A failed connection exits here with psql's own error.
installed=$(psql -tAc "SELECT to_regclass('$MW_DB_SCHEMA.mwuser') IS NOT NULL")

if [ "$installed" != t ]; then
  echo "entrypoint: empty database, running first-boot install" >&2
  # The installer refuses to run while a config file exists.
  # Its generated LocalSettings.php goes to /tmp and is discarded.
  env -u MW_CONFIG_FILE php "$IP/maintenance/run.php" install \
    --dbtype postgres \
    --dbserver "$PGHOST" \
    --dbport "$PGPORT" \
    --dbname "$PGDATABASE" \
    --dbschema "$MW_DB_SCHEMA" \
    --dbuser "$PGUSER" \
    --dbpass "$PGPASSWORD" \
    --server "https://wiki.$DOMAIN" \
    --scriptpath="" \
    --pass "$MW_ADMIN_PASSWORD" \
    --confpath /tmp \
    "$MW_SITENAME" "$MW_ADMIN_USER"
fi

# Covers a MediaWiki version bump and the Cargo/PageForms tables alike.
php "$IP/maintenance/run.php" update --quick

# pages/<Namespace>/<Title>.wikitext becomes <Namespace>:<Title>.
# Unchanged files are skipped, and an on-wiki edit is overwritten by the file.
for dir in /var/www/pages/*/; do
  [ -d "$dir" ] || continue
  php "$IP/maintenance/run.php" importTextFiles --overwrite \
    --summary "Imported from git" --prefix "$(basename "$dir"):" "$dir"*.wikitext \
    || echo "entrypoint: page import from $dir failed" >&2
done

# install and update run as root; Apache is www-data.
chown -R www-data:www-data "$IP/cache" /var/log/mediawiki

# Otherwise WebStart.php serves "set up the wiki first" with HTTP 200.
runuser -u www-data -- test -r "$MW_CONFIG_FILE" \
  || { echo "entrypoint: www-data cannot read $MW_CONFIG_FILE" >&2; exit 1; }

exec apache2-foreground
