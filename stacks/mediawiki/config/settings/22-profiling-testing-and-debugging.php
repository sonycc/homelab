<?php
// == Profiling, testing and debugging ==

// === Debug ===

// The mediawiki_logs volume. Look up the [id] from an error page here.
$wgDebugLogGroups['exception'] = '/var/log/mediawiki/exception.log';
$wgDebugLogGroups['fatal'] = '/var/log/mediawiki/exception.log';
$wgDebugLogGroups['captcha'] = '/var/log/mediawiki/captcha.log';

// Prerequisite for a future fail2ban jail; inert until fail2ban is running again.
// $wgDebugLogGroups['authevents'] = '/var/log/mediawiki/auth.log';
