<?php
// == Database settings ==

// PG* names, shared with psql in entrypoint.sh.
$wgDBtype = 'postgres';
$wgDBserver = wikiEnv( 'PGHOST', 'postgres' );
$wgDBname = wikiEnv( 'PGDATABASE', 'mediawiki' );
$wgDBuser = wikiEnv( 'PGUSER', 'mediawiki' );
$wgDBpassword = wikiEnv( 'PGPASSWORD' );
// Must match --dbschema in entrypoint.sh, or update.php looks in an empty schema
// and reports the wiki as older than 1.35.
$wgDBmwschema = wikiEnv( 'MW_DB_SCHEMA', 'mediawiki' );

// The mediawiki_logs volume.
$wgDBerrorLog = '/var/log/mediawiki/dberror.log';

// === PostgreSQL-specific ===

$wgDBport = wikiEnv( 'PGPORT', '5432' );
