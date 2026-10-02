<?php
// == Server URLs and file paths ==

// NPM terminates TLS and speaks HTTP to this container, so without an explicit
// https server MediaWiki emits http:// links on an https site.
$wgScriptPath = '';
$wgServer = 'https://wiki.' . wikiEnv( 'DOMAIN' );
$wgCanonicalServer = $wgServer;
$wgResourceBasePath = $wgScriptPath;
// The image's short-url.conf routes every non-file path to index.php.
$wgArticlePath = '/wiki/$1';

// Served by Apache from the ./logo bind mount, so it shows on the login page too.
$wgLogos = [
	'1x' => "$wgResourceBasePath/logo/logo.svg",
	'icon' => "$wgResourceBasePath/logo/logo.svg",
];
$wgFavicon = "$wgResourceBasePath/logo/logo.svg";
