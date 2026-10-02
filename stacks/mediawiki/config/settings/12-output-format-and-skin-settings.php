<?php
// == Output format and skin settings ==

// === Skins ===

// Added by the Dockerfile. Follows the device's light or dark setting,
// and each player can pick light, dark or auto in the skin's own preferences panel.
$wgDefaultSkin = 'citizen';
wfLoadSkin( 'Citizen' );
wfLoadSkin( 'Vector' );
// Legacy Vector. Vector 2022 stays selectable in preferences.
$wgSkipSkins = [ 'vector' ];
