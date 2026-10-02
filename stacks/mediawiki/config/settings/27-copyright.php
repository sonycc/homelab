<?php
// == Copyright ==

// The site default. Pages under another licence carry {{License}},
// from pages/Template/License.wikitext.
$wgRightsText = 'CC BY-NC-ND 4.0';
$wgRightsUrl = 'https://creativecommons.org/licenses/by-nc-nd/4.0/';

$wikiMessages += [
	'Copyright' => 'Content is by ' . wikiEnv( 'MW_LICENSE_HOLDER' ) . ' and contributors,'
		. ' available under $1 unless otherwise noted.',
	'Copyrightwarning' => 'By saving, you license your contribution to the public under $2,'
		. ' and permit other contributors to edit and adapt it on this wiki.'
		. ' To ask for a different licence for your own work, write the licence you want'
		. ' on the first line of the page and a Loremaster will set it.'
		. ' Material from a published game must name its source and licence with'
		. ' <code><nowiki>{{License}}</nowiki></code> at the bottom of the page.',
];
