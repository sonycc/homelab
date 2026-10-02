<?php
// == Category ==

// MediaWiki's default, set explicitly. Neither numeric nor uca-* works on postgres:
// their sort keys hold bytes a text column cannot store. Order numbers with
// {{DEFAULTSORT:Level 02}} in the template instead.
$wgCategoryCollation = 'uppercase';
