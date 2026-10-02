<?php
// == HTTP proxy (CDN) settings ==

// Without this every request looks like it came from nginx: anonymous edits and
// IP blocks would target 172.21.0.x, and the login throttle would key on nginx,
// so three bad logins from one stranger would lock out everyone.
$wgCdnServersNoPurge = [ '172.21.0.0/16' ];
$wgUsePrivateIPs = false;
