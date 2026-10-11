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

// Posts to the Discord webhook in the env variable $webhookEnv, if it is set.
// Pings only the users and roles in DISCORD_MENTIONS_<type>, never a name in the message.
function wikiDiscord( string $webhookEnv, string $type, string $content ): void {
	$webhook = wikiEnv( $webhookEnv );
	if ( $webhook === '' ) {
		return;
	}
	$mentions = wikiEnv( "DISCORD_MENTIONS_$type" );
	preg_match_all( '/<@!?(\d+)>/', $mentions, $users );
	preg_match_all( '/<@&(\d+)>/', $mentions, $roles );
	$request = \MediaWiki\MediaWikiServices::getInstance()->getHttpRequestFactory()->create( $webhook, [
		'method' => 'POST',
		'postData' => json_encode( [
			'content' => trim( "$mentions $content" ),
			'allowed_mentions' => [ 'parse' => [], 'users' => $users[1], 'roles' => $roles[1] ],
		] ),
		'timeout' => 5,
	], __METHOD__ );
	$request->setHeader( 'Content-Type', 'application/json' );
	$request->execute();
}

// To the admins' channel. Sent after the response, so a slow or failing webhook never holds up the request.
function wikiNotify( string $type, string $content ): void {
	\MediaWiki\Deferred\DeferredUpdates::addCallableUpdate( static function () use ( $type, $content ) {
		wikiDiscord( 'DISCORD_WEBHOOK_URL_NOTIFICATIONS', $type, $content );
	} );
}

// To the server owner's channel. Sent at once, since a failing request may never run its deferred updates.
// The same message is sent at most once an hour per container, so a broken page viewed repeatedly posts once.
function wikiWarn( string $type, string $content ): void {
	$cache = \MediaWiki\MediaWikiServices::getInstance()->getLocalServerObjectCache();
	if ( !$cache->add( $cache->makeKey( 'homelab-warn', md5( $content ) ), 1, 3600 ) ) {
		return;
	}
	wikiDiscord( 'DISCORD_WEBHOOK_URL_WARNINGS', $type, $content );
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
