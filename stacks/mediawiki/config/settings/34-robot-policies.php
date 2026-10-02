<?php
// == Robot policies ==

// Not $wgDefaultRobotPolicy: Approved Revs sets index,follow on every approved
// page, and raising noindex to index is deprecated in 1.43. Lowering it last is not.
$wgHooks['BeforePageDisplay'][] = static function ( $out, $skin ) {
	$out->setRobotPolicy( 'noindex,nofollow' );
};
