use strict;
use warnings;
use Test::More tests => 6;

# Plain `use Class::Inspector;` (and the explicit empty-list form)
# should not export anything, preserving the classic method-only
# interface.

package NoImport;

use Class::Inspector;

::ok( ! __PACKAGE__->can('installed'), "use Class::Inspector; does not export installed" );

package NoImportEmpty;

use Class::Inspector ();

::ok( ! __PACKAGE__->can('installed'), "use Class::Inspector (); does not export installed" );

package ExplicitImport;

use Class::Inspector qw( installed );

::ok( __PACKAGE__->can('installed'), "use Class::Inspector qw( installed ); exports installed" );
::ok( installed('Class::Inspector'), "imported installed function works" );

package TagImport;

use Class::Inspector qw( :ALL );

::ok( __PACKAGE__->can('function_exists'), "use Class::Inspector qw( :ALL ); exports function_exists" );
::ok( __PACKAGE__->can('resolved_filename'), "use Class::Inspector qw( :ALL ); exports resolved_filename" );
