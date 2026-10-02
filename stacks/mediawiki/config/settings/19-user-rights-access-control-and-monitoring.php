<?php
// == User rights, access control and monitoring ==

// Roles are granted by admins at Special:UserRights.
//
// | Group      | Adds                                                         |
// |------------|--------------------------------------------------------------|
// | user       | own User: pages, every talk page                             |
// | player     | edit anywhere else, upload up to 20 MB                       |
// | loremaster | approve, move, protect, patrol, block, minor edits,          |
// |            | bulk edit, upload up to 99 MB                                |
// | sysop      | templates, modules and forms, delete, everything else        |
$wgAvailableRights[] = 'edit-anywhere';
$wgAvailableRights[] = 'edit-structure';
$wgAvailableRights[] = 'upload-large';

// Open registration. Anonymous visitors get the Main Page, login and signup only.
$wgGroupPermissions['*']['read'] = false;
$wgGroupPermissions['*']['edit'] = false;
$wgGroupPermissions['*']['createaccount'] = true;

$wgGroupPermissions['user']['edit'] = true;
$wgGroupPermissions['user']['upload'] = false;
$wgGroupPermissions['user']['move'] = false;
// A minor edit is hidden from watchlists that hide minor edits.
$wgGroupPermissions['user']['minoredit'] = false;
$wgGroupPermissions['loremaster']['minoredit'] = true;
$wgGroupPermissions['sysop']['minoredit'] = true;

$wgGroupPermissions['player']['edit-anywhere'] = true;
$wgGroupPermissions['player']['upload'] = true;

$wgGroupPermissions['loremaster']['edit-anywhere'] = true;
$wgGroupPermissions['loremaster']['upload'] = true;
$wgGroupPermissions['loremaster']['upload-large'] = true;
$wgGroupPermissions['loremaster']['approverevisions'] = true;
$wgGroupPermissions['loremaster']['viewapprover'] = true;
$wgGroupPermissions['loremaster']['move'] = true;
$wgGroupPermissions['loremaster']['protect'] = true;
$wgGroupPermissions['loremaster']['editprotected'] = true;
$wgGroupPermissions['loremaster']['patrol'] = true;
$wgGroupPermissions['loremaster']['autopatrol'] = true;
$wgGroupPermissions['loremaster']['block'] = true;

// Everyone is autoconfirmed on signup, so that level protects nothing.
$wgRestrictionLevels = [ '', 'sysop' ];

$wgGroupPermissions['sysop']['edit-anywhere'] = true;
$wgGroupPermissions['sysop']['edit-structure'] = true;
$wgGroupPermissions['sysop']['upload'] = true;
$wgGroupPermissions['sysop']['upload-large'] = true;
$wgGroupPermissions['sysop']['approverevisions'] = true;
$wgGroupPermissions['sysop']['move'] = true;
$wgGroupPermissions['sysop']['renameuser'] = true;

// The only groups Special:UserRights offers.
// Admins are made with createAndPromote --sysop.
$wgAddGroups['sysop'] = [ 'player', 'loremaster' ];
$wgRemoveGroups['sysop'] = [ 'player', 'loremaster' ];
unset( $wgGroupPermissions['bureaucrat'] );
unset( $wgGroupPermissions['suppress'] );
// Echo registers this after the settings files run.
$wgExtensionFunctions[] = static function () {
	global $wgGroupPermissions;
	unset( $wgGroupPermissions['push-subscription-manager'] );
};

// Template, Module (Scribunto) and Form (Page Forms).
$wgNamespaceProtection[NS_TEMPLATE] = [ 'edit-structure' ];
$wgNamespaceProtection[828] = [ 'edit-structure' ];
$wgNamespaceProtection[106] = [ 'edit-structure' ];

$wgHooks['getUserPermissionsErrors'][] = static function ( $title, $user, $action, &$result ) {
	if ( $action !== 'edit' || $title->isTalkPage() || $user->isAllowed( 'edit-anywhere' ) ) {
		return true;
	}
	if ( $title->getNamespace() === NS_USER && $title->getRootText() === $user->getName() ) {
		return true;
	}
	$result = [ 'rawmessage', 'Until you are given the Player role, you can only edit your own user pages and contribute to any discussions in talk pages.' ];
	return false;
};

$wikiMessages += [
	// Shown on a missing page the viewer cannot create, for any reason.
	'Noarticletext-nopermission' => 'This page does not exist yet.'
		. ' Until an admin gives you the Player role, you can only create pages under'
		. ' [[Special:MyPage|your own user page]], such as your character and background.'
		. ' Templates, modules and forms are created by admins.',
	'Group-player' => 'Players',
	'Group-player-member' => 'Player',
	'Group-loremaster' => 'Loremasters',
	'Group-loremaster-member' => 'Loremaster',
	'Group-sysop' => 'Admins',
	'Group-sysop-member' => 'Admin',
	'Group-interface-admin' => 'Site developers',
	'Group-interface-admin-member' => 'Site developer',
	'Protect-level-sysop' => 'Allow only Loremasters and admins',
	'Right-edit-anywhere' =>'Edit pages outside your own user space',
	'Right-edit-structure' => 'Edit templates, modules and forms',
	'Right-upload-large' => 'Upload files up to 99 MB',
];

// === Access ===

// Login and signup are reachable with read denied, but named explicitly because
// the whole point of open registration is that these must never be gated.
$wgWhitelistRead = [
	// Public landing page. Pages it links to still need a login.
	'Main Page',
	'Special:CreateAccount',
	'Special:UserLogin',
	'Special:UserLogout',
];
