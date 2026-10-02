# 1.43 LTS, supported to December 2027. A major bump also moves EXT_BRANCH below.
ARG MEDIAWIKI_VERSION=1.43.9

FROM alpine:3.23 AS extensions

ARG EXT_BRANCH=REL1_43
# Not a Wikimedia skin, so no REL branch. Requires MediaWiki >= 1.43.
ARG CITIZEN_TAG=v3.23.0

RUN apk add --no-cache git

WORKDIR /extensions

RUN set -eux; \
    for ext in Cargo PageForms ApprovedRevs; do \
      git clone --depth 1 --branch "$EXT_BRANCH" \
        "https://github.com/wikimedia/mediawiki-extensions-$ext.git" "$ext"; \
      rm -rf "$ext/.git"; \
    done

WORKDIR /skins

RUN set -eux; \
    git clone --depth 1 --branch "$CITIZEN_TAG" \
      https://github.com/StarCitizenTools/mediawiki-skins-Citizen.git Citizen; \
    rm -rf Citizen/.git

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
