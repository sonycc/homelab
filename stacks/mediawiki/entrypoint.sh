#!/bin/bash
# Config comes from MW_CONFIG_FILE, so $IP/LocalSettings.php never exists.
set -euo pipefail

IP=/var/www/html
schema="\"$MW_DB_SCHEMA\""

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
    --pass "$MW_ADMIN_PASSWORD" \
    --confpath /tmp \
    "$MW_SITENAME" "$MW_ADMIN_USER"
fi

# Covers a MediaWiki version bump and the Cargo/PageForms tables alike.
php "$IP/maintenance/run.php" update --quick

# pages/<Namespace>/<Title>.wikitext becomes <Namespace>:<Title>.
# Unchanged files are skipped.
for dir in /var/www/pages/*/; do
  [ -d "$dir" ] || continue
  php "$IP/maintenance/run.php" importTextFiles --overwrite \
    --summary "Imported from git" --prefix "$(basename "$dir"):" "$dir"*.wikitext \
    || echo "entrypoint: page import from $dir failed" >&2
done

# Approved Revs never approves the import's maintenance user, so every category page from pages/ would wait for approval.
# With BlankIfUnapproved, its links are then built from a blank page, and its #default_form is lost.
# The file is the reviewed source, so its revision is approved here, and the category pages' links rebuilt.
approve_imported_categories() {
  local file title titles=() list changed
  for file in /var/www/pages/Category/*.wikitext; do
    [ -e "$file" ] || continue
    title=$(basename "$file" .wikitext)
    title=${title// /_}
    titles+=("'${title//\'/\'\'}'")
  done
  [ ${#titles[@]} -gt 0 ] || return 0
  list=$(IFS=,; echo "${titles[*]}")

  changed=$(psql -qtAc "INSERT INTO $schema.approved_revs (page_id, rev_id, approver_id, approval_date)
    SELECT page_id, page_latest, 0, now() FROM $schema.page
    WHERE page_namespace = 14 AND page_title IN ($list)
    ON CONFLICT (page_id) DO UPDATE SET rev_id = EXCLUDED.rev_id, approval_date = EXCLUDED.approval_date
    WHERE approved_revs.rev_id IS DISTINCT FROM EXCLUDED.rev_id
    RETURNING page_id") || return 1
  [ -n "$changed" ] || return 0

  echo "entrypoint: approved $(wc -l <<<"$changed") imported category pages" >&2
  php "$IP/maintenance/run.php" refreshLinks --namespace 14
}
approve_imported_categories || echo "entrypoint: approving imported category pages failed" >&2

# Builds the Cargo table of each #cargo_declare in pages/Template/ that is new or changed,
# what the template's Create data table and Recreate data buttons do.
# Every row comes from page text, so a rebuild loses nothing.
# The hash of each declaration last built is kept in the database, so an unchanged one is skipped.
# Rows are stored from template parameters alone, so the order tables are built in does not matter.
rebuild_cargo_tables() {
  local file declaration table hash built exists
  psql -qc "CREATE TABLE IF NOT EXISTS $schema.homelab_cargo_declarations (
    main_table TEXT PRIMARY KEY, sha256 TEXT NOT NULL)" || return 1

  for file in /var/www/pages/Template/*.wikitext; do
    declaration=$(awk 'index($0, "{{#cargo_declare:") { on = 1 } on { print } on && substr($0, 1, 2) == "}}" { exit }' "$file")
    [ -n "$declaration" ] || continue
    table=$(sed -n 's/.*_table=\([A-Za-z0-9_]*\).*/\1/p' <<<"$declaration" | head -n 1)
    if [ -z "$table" ]; then
      echo "entrypoint: no _table= in the #cargo_declare of $file" >&2
      continue
    fi
    hash=$(sha256sum <<<"$declaration" | cut -d' ' -f1)

    built=$(psql -tAc "SELECT sha256 FROM $schema.homelab_cargo_declarations WHERE main_table = '$table'")
    exists=$(psql -tAc "SELECT 1 FROM $schema.cargo_tables WHERE main_table = '$table'")
    [ "$built" = "$hash" ] && [ "$exists" = 1 ] && continue

    echo "entrypoint: building Cargo table $table" >&2
    if php "$IP/extensions/Cargo/maintenance/cargoRecreateData.php" --table "$table" --quiet \
      && [ "$(psql -tAc "SELECT 1 FROM $schema.cargo_tables WHERE main_table = '$table'")" = 1 ]; then
      psql -qc "INSERT INTO $schema.homelab_cargo_declarations VALUES ('$table', '$hash')
        ON CONFLICT (main_table) DO UPDATE SET sha256 = EXCLUDED.sha256"
    else
      echo "entrypoint: building Cargo table $table failed, retried on the next start" >&2
    fi
  done
}
rebuild_cargo_tables || echo "entrypoint: Cargo table check failed" >&2

# install and update run as root; Apache is www-data.
chown -R www-data:www-data "$IP/cache" /var/log/mediawiki

# Otherwise WebStart.php serves "set up the wiki first" with HTTP 200.
runuser -u www-data -- test -r "$MW_CONFIG_FILE" \
  || { echo "entrypoint: www-data cannot read $MW_CONFIG_FILE" >&2; exit 1; }

exec apache2-foreground
