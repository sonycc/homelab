<?php
// == Extensions ==
// Bundled with the tarball unless noted; `ls extensions/` in the container lists the rest.

wfLoadExtension( 'WikiEditor' );
wfLoadExtension( 'ParserFunctions' );
wfLoadExtension( 'Cite' );
wfLoadExtension( 'CategoryTree' );
wfLoadExtension( 'ReplaceText' );
wfLoadExtension( 'Nuke' );
wfLoadExtension( 'Echo' );
wfLoadExtension( 'Thanks' );
// Linter is a hard dependency of DiscussionTools.
wfLoadExtension( 'Linter' );
wfLoadExtension( 'DiscussionTools' );
wfLoadExtension( 'TemplateData' );
wfLoadExtension( 'CodeEditor' );
// Uses the python3 the base image installs for it.
wfLoadExtension( 'SyntaxHighlight_GeSHi' );

// === Interwiki ===

// Prefixes like [[srd:Fireball]], managed at Special:Interwiki.
wfLoadExtension( 'Interwiki' );
$wgGroupPermissions['sysop']['interwiki'] = true;

// === ConfirmEdit ===

// Open registration on an internet-facing wiki attracts spambots, and with email
// disabled there is no confirmation step to fall back on. A question only your
// players can answer defeats generic bots where a maths captcha does not.
wfLoadExtensions( [ 'ConfirmEdit', 'ConfirmEdit/QuestyCaptcha' ] );
$wgCaptchaClass = 'QuestyCaptcha';
// Signup only. Login is covered by $wgPasswordAttemptThrottle.
$wgCaptchaTriggers['createaccount'] = true;
$wgCaptchaTriggers['addurl'] = false;
$wgCaptchaTriggers['badlogin'] = false;
$wgCaptchaTriggers['badloginperuser'] = false;
// From .env, because this repo is public and the answer is the whole defence.
$wgCaptchaQuestions = [
	wikiEnv( 'MW_CAPTCHA_QUESTION' ) => array_map( 'trim', explode( '|', wikiEnv( 'MW_CAPTCHA_ANSWERS' ) ) ),
];
// Checked before the attempt is counted, so 2 means three wrong answers per IP per day.
$wgRateLimits['badcaptcha']['ip'] = [ 2, 60 * 60 * 24 ];

// === OATHAuth ===

// Optional for everyone.
wfLoadExtension( 'OATHAuth' );
$wgGroupPermissions['user']['oathauth-enable'] = true;

// === VisualEditor ===

// Parsoid is in core since 1.35, so VisualEditor needs no separate service.
wfLoadExtension( 'VisualEditor' );
$wgDefaultUserOptions['visualeditor-enable'] = 1;
$wgVisualEditorEnableWikitext = true;
$wgVisualEditorUseSingleEditTab = true;
$wgDefaultUserOptions['visualeditor-tabs'] = 'remember-last';

// === Scribunto ===

// LuaSandbox is compiled into the image.
wfLoadExtension( 'Scribunto' );
$wgScribuntoDefaultEngine = 'luasandbox';
$wgScribuntoUseCodeEditor = true;
$wgScribuntoUseGeSHi = true;

// === Cargo and Page Forms ===

// Added by the Dockerfile.
wfLoadExtension( 'Cargo' );
wfLoadExtension( 'PageForms' );
// A list of up to 25 values loads with the form and opens on click.
// A longer one searches the wiki as you type, so a page made in another tab shows up without a reload.
$wgPageFormsMaxLocalAutocompleteValues = 25;
// Matches anywhere in a value, not only at word starts.
// The word-start search writes an apostrophe separator as \', which PostgreSQL rejects.
$wgPageFormsAutocompleteOnAllChars = true;

// Dark mode and form checks, from config/ rather than MediaWiki:Common.css and Common.js.
$wgResourceModules['homelab.pageforms.styles'] = [
	'styles' => 'css/page-forms.css',
	'localBasePath' => dirname( __DIR__ ),
];
$wgResourceModules['homelab.pageforms'] = [
	'scripts' => 'js/page-forms.js',
	'localBasePath' => dirname( __DIR__ ),
];
$wgHooks['BeforePageDisplay'][] = static function ( $out, $skin ) {
	$out->addModuleStyles( 'homelab.pageforms.styles' );
	$out->addModules( 'homelab.pageforms' );
};

// Special:CreateClass writes templates and forms, which only admins can save.
$wgGroupPermissions['user']['createclass'] = false;
$wgGroupPermissions['sysop']['createclass'] = true;
// Special:MultiPageEdit, the spreadsheet editor.
$wgGroupPermissions['user']['multipageedit'] = false;
$wgGroupPermissions['loremaster']['multipageedit'] = true;
$wgGroupPermissions['sysop']['multipageedit'] = true;

// === TabberNeue ===

// Added by the Dockerfile. Module:Stats builds the per-system stat tabs with it.
wfLoadExtension( 'TabberNeue' );
// A message of - switches its tracking category off, which every page with stat tabs would otherwise join.
$wikiMessages += [
	'Tabberneue-tabber-category' => '-',
];

// === Approved Revs ===

// Added by the Dockerfile. Who may approve is in
// 19-user-rights-access-control-and-monitoring.php.
wfLoadExtension( 'ApprovedRevs' );

// array_plus merge: the defaults (Main, User, Project, File, Template, Help)
// stay on unless switched off by name.
$egApprovedRevsEnabledNamespaces[NS_USER] = false;
// Admin-only already, and pages/ imports are never approved automatically.
$egApprovedRevsEnabledNamespaces[NS_TEMPLATE] = false;
$egApprovedRevsEnabledNamespaces[NS_CATEGORY] = true;
$egApprovedRevsShowNotApprovedMessage = true;
// Also what lets a new page by an approver approve itself on save.
$egApprovedRevsBlankIfUnapproved = true;

// blankpageshown is the one readers see while BlankIfUnapproved is on.
$wikiMessages += [
	'Approvedrevs-noapprovedrevision' => 'This page is awaiting approval and is not considered lore.',
	'Approvedrevs-blankpageshown' => 'This page is awaiting approval and is not considered lore.',
];
