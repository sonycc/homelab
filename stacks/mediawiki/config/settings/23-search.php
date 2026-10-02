<?php
// == Search ==

// Every content namespace. Talk pages and template, module and form code stay
// out, and can still be ticked on the search page.
$wgNamespacesToBeSearchedDefault = [
	NS_MAIN => true,
	NS_USER => true,
	NS_PROJECT => true,
	NS_FILE => true,
	NS_HELP => true,
	NS_CATEGORY => true,
];
