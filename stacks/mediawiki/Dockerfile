# 1.43 LTS, supported to December 2027. A major bump means checking each tag below still supports it.
ARG MEDIAWIKI_VERSION=1.43.9

FROM alpine:3.23 AS extensions

# Release tags, not REL branches: these three are versioned across MediaWiki releases,
# and their REL branches stay frozen at whatever was current when cut.
# Requires MediaWiki >= 1.42.
ARG CARGO_TAG=3.9.4
# Requires MediaWiki >= 1.40.
ARG PAGEFORMS_TAG=6.0.11
# Requires MediaWiki >= 1.42.
ARG APPROVEDREVS_TAG=2.4.2
# Requires MediaWiki >= 1.43.
ARG CITIZEN_TAG=v3.24.0
# Requires MediaWiki >= 1.43.
ARG TABBERNEUE_TAG=v4.1.0

RUN apk add --no-cache git

RUN set -eux; \
    for spec in \
      "extensions/Cargo $CARGO_TAG wikimedia/mediawiki-extensions-Cargo" \
      "extensions/PageForms $PAGEFORMS_TAG wikimedia/mediawiki-extensions-PageForms" \
      "extensions/ApprovedRevs $APPROVEDREVS_TAG wikimedia/mediawiki-extensions-ApprovedRevs" \
      "extensions/TabberNeue $TABBERNEUE_TAG StarCitizenTools/mediawiki-extensions-TabberNeue" \
      "skins/Citizen $CITIZEN_TAG StarCitizenTools/mediawiki-skins-Citizen"; do \
      set -- $spec; \
      git clone --depth 1 --branch "$2" "https://github.com/$3.git" "/$1"; \
      rm -rf "/$1/.git"; \
    done

FROM mediawiki:${MEDIAWIKI_VERSION}

# libpq-dev stays: pgsql.so links libpq5, and apt cannot see that.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libpq-dev postgresql-client; \
    docker-php-ext-install -j"$(nproc)" pgsql exif; \
    rm -rf /var/lib/apt/lists/*

COPY --from=extensions --chown=www-data:www-data /extensions/ /var/www/html/extensions/
COPY --from=extensions --chown=www-data:www-data /skins/ /var/www/html/skins/

# Matches $wgMaxUploadSize.
COPY <<EOF /usr/local/etc/php/conf.d/mediawiki-uploads.ini
upload_max_filesize = 99M
post_max_size = 100M
EOF

# The image has no php.ini, and PHP's own default prints errors into the page.
# Errors go to Apache's log, which is docker logs.
COPY <<EOF /usr/local/etc/php/conf.d/mediawiki-errors.ini
display_errors = Off
display_startup_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED
EOF

COPY <<EOF /etc/apache2/conf-enabled/mediawiki-uploads.conf
<Directory /var/www/html/images>
  php_admin_flag engine off
  Header set X-Content-Type-Options nosniff
  Options -Indexes
</Directory>
EOF

RUN set -eux; \
    a2enmod headers; \
    echo 'ServerName localhost' > /etc/apache2/conf-enabled/servername.conf; \
    apache2ctl configtest
