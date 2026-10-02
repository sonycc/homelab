<?php
// == Email settings ==

// No SMTP here, and a half-working mailer makes password resets appear to
// succeed. Reset with maintenance/run.php changePassword instead.
$wgEnableEmail = false;
$wgEnableUserEmail = false;
$wgEmailAuthentication = false;
