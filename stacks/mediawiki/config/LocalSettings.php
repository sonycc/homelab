<?php
// Mounted read-only at /var/www/config and loaded via MW_CONFIG_FILE.
// The installer's own output goes to /tmp and is discarded, so
// this directory is the only config the wiki loads.
//
// settings/ has one file per section of
// https://www.mediawiki.org/wiki/Manual:Configuration_settings, numbered in the
// manual's order, and only for sections that set something.
// Anything not set there is MediaWiki's default.

if ( !defined( 'MEDIAWIKI' ) ) {
	exit;
}

function wikiEnv( string $name, string $default = '' ): string {
	$value = getenv( $name );
	return ( $value === false || $value === '' ) ? $default : $value;
}

// Interface wording, added to by the settings files.
// Kept in git rather than as MediaWiki: pages. The API ignores these by default,
// so errors raised from hooks use rawmessage instead.
$wikiMessages = [];

foreach ( glob( __DIR__ . '/settings/*.php' ) as $settingsFile ) {
	require_once $settingsFile;
}

$wgHooks['MessagesPreLoad'][] = static function ( $title, &$message, $code ) use ( $wikiMessages ) {
	$key = explode( '/', $title )[0];
	if ( isset( $wikiMessages[$key] ) ) {
		$message = $wikiMessages[$key];
	}
	return true;
};
