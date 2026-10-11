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
$wgHooks['LocalUserCreated'][] = static function ( $user, $autocreated ) {
	$name = $user->getName();
	$rights = \MediaWiki\SpecialPage\SpecialPage::getTitleFor( 'UserRights', $name )->getCanonicalURL();
	wikiNotify( 'SIGNUP', "New wiki account: **$name** · give a role: <$rights>" );
};

// Sends a signed-in user without a profile from the Main Page to the profile form.
// A profile is a user page in Category:Players, which Template:Player adds.
// Only the Main Page redirects, so every other page stays reachable without one.
$wgHooks['MediaWikiPerformAction'][] = static function ( $output, $article, $title, $user, $request, $mediaWiki ) {
	if ( !$user->isRegistered() || !$title->isMainPage() || $mediaWiki->getAction() !== 'view' ) {
		return true;
	}
	$profile = $user->getUserPage();
	if ( $profile->exists() && array_key_exists( 'Category:Players', $profile->getParentCategories() ) ) {
		return true;
	}
	$form = \MediaWiki\SpecialPage\SpecialPage::getTitleFor( 'FormEdit', 'Player/' . $profile->getPrefixedText() );
	$output->redirect( $form->getFullURL( [ 'wpSummary' => 'initial profile creation' ] ) );
	return false;
};

// Bot password logins skip TOTP. Turn on when the Discord bot gets a wiki account.
$wgEnableBotPasswords = true;
