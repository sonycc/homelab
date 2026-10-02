<?php
// == User accounts, authentication ==

// Every group, since per-group policies merge by taking the stricter value.
$wgPasswordPolicy['policies']['default']['MinimalPasswordLength'] = [
	'value' => 12,
	'suggestChangeOnLogin' => true,
];

// No fail2ban jail is running, so this is the whole brute-force perimeter.
// Requires $wgMainCacheType and the proxy settings to be meaningful.
$wgPasswordAttemptThrottle = [
	[ 'count' => 3, 'seconds' => 60 * 15 ],
	[ 'count' => 50, 'seconds' => 60 * 60 * 48 ],
];

// One account per IP. Leans on the same proxy handling as the password
// throttle: without it every registration counts against nginx.
// Held in APCu, so a container restart resets it.
$wgAccountCreationThrottle = [ [ 'count' => 1, 'seconds' => 60 * 60 * 24 * 365 ] ];

// Posts each new account to Discord, so an admin can give it a role.
// Sent after the response, so a slow or failing webhook never affects signup.
$wgHooks['LocalUserCreated'][] = static function ( $user, $autocreated ) {
	$webhook = wikiEnv( 'MW_SIGNUP_WEBHOOK_URL' );
	if ( $webhook === '' ) {
		return;
	}
	$name = $user->getName();
	$rights = \MediaWiki\SpecialPage\SpecialPage::getTitleFor( 'UserRights', $name )->getCanonicalURL();
	\MediaWiki\Deferred\DeferredUpdates::addCallableUpdate( static function () use ( $webhook, $name, $rights ) {
		$request = \MediaWiki\MediaWikiServices::getInstance()->getHttpRequestFactory()->create( $webhook, [
			'method' => 'POST',
			'postData' => json_encode( [
				'content' => "New wiki account: **$name** · give a role: <$rights>",
				'allowed_mentions' => [ 'parse' => [] ],
			] ),
			'timeout' => 5,
		], __METHOD__ );
		$request->setHeader( 'Content-Type', 'application/json' );
		$request->execute();
	} );
};

// Bot password logins skip TOTP. Turn on when the Discord bot gets a wiki account.
$wgEnableBotPasswords = false;
