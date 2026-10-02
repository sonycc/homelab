<?php
// == Cache ==

// APCu ships in the image. The default CACHE_DB would put every cache write
// through postgres.
$wgMainCacheType = CACHE_ACCEL;
// Survive a container restart.
$wgSessionCacheType = CACHE_DB;
// Localisation cache as files instead of postgres rows.
// entrypoint.sh hands the directory to www-data.
$wgCacheDirectory = "$IP/cache";

// === Parser Cache ===

// Survive a container restart.
$wgParserCacheType = CACHE_DB;
