// Page Forms can't require a different value in each row of a multiple-instance template.
// Blocks saving a species or class whose rows pick the same system twice.
( function () {
	var form = document.getElementById( 'pfForm' );
	if ( !form ) {
		return;
	}
	form.addEventListener( 'submit', function ( event ) {
		var seen = {};
		var repeated = [];
		var selects = form.querySelectorAll( 'select[name^="Species system["][name$="[system]"], select[name^="Class system["][name$="[system]"]' );
		Array.prototype.forEach.call( selects, function ( select ) {
			// The hidden row new rows are copied from.
			if ( select.name.indexOf( '[num]' ) !== -1 || !select.value ) {
				return;
			}
			if ( seen[ select.value ] && repeated.indexOf( select.value ) === -1 ) {
				repeated.push( select.value );
			}
			seen[ select.value ] = true;
		} );
		if ( repeated.length ) {
			event.preventDefault();
			event.stopImmediatePropagation();
			// eslint-disable-next-line no-alert
			alert( 'Each system can only be listed once. Remove the extra row for: ' + repeated.join( ', ' ) );
		}
	}, true );

	// Create new links open the other form in a new tab, so this one isn't lost.
	// Delegated, because the rows Add buttons make are copied in later.
	form.addEventListener( 'click', function ( event ) {
		var link = event.target.closest( '.pf-create-new a' );
		if ( link ) {
			event.preventDefault();
			window.open( link.href, '_blank', 'noopener' );
		}
	} );
}() );
