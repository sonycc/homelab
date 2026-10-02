<?php
// == Files and file uploads ==
// Who may upload is in 19-user-rights-access-control-and-monitoring.php.

// The images volume is the half of this wiki that pg_dumpall does not cover.
$wgEnableUploads = true;
$wgFileExtensions = [ 'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg', 'pdf', 'mp3', 'ogg' ];

// The largest role's limit, and equal to upload_max_filesize in the Dockerfile.
// Smaller roles are enforced by the UploadVerifyUpload hook below.
$wgMaxUploadSize = 99 * 1024 * 1024;

$wgNativeImageLazyLoading = true;

$wgHooks['UploadVerifyUpload'][] = static function ( $upload, $user, $props, $comment, $pageText, &$error ) {
	if ( !$user->isAllowed( 'upload-large' ) && $upload->getFileSize() > 20 * 1024 * 1024 ) {
		$error = [ 'rawmessage', 'Your role can only upload files up to 20 MB. Please let the admin know if you need to upload larger files.' ];
		return false;
	}
	return true;
};

// === Images ===

// ==== ImageMagick ====

// ImageMagick ships in the image; the default falls back to GD, which thumbnails
// worse and handles fewer formats.
$wgUseImageMagick = true;

// ==== SVG ====

$wgSVGConverter = 'rsvg';
