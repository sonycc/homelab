#!/bin/sh
# Runs as www-data on every start, after install or upgrade.
# Settings here win over changes made in the admin UI.
set -eu

# https://docs.nextcloud.com/server/latest/admin_manual/configuration_server/background_jobs_configuration.html
php /var/www/html/occ background:cron

# Below Cloudflare's 100 MB request cap.
# https://docs.nextcloud.com/server/latest/admin_manual/configuration_files/big_file_upload_configuration.html
php /var/www/html/occ config:app:set files max_chunk_size --value 52428800

# Heavy background jobs run between 01:00 and 05:00 UTC.
php /var/www/html/occ config:system:set maintenance_window_start --type integer --value 1

php /var/www/html/occ config:system:set default_phone_region --value NO
