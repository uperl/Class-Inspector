package Class::Inspector::Functions;

use 5.006;
use strict;
use warnings;
use Exporter         ();
use Class::Inspector ();
use base qw( Exporter );

# ABSTRACT: Get information about a class and its structure
# VERSION

BEGIN {

  our @EXPORT = qw(
    installed
    loaded

    filename
    functions
    methods

    subclasses
  );

  our @EXPORT_OK = qw(
    resolved_filename
    loaded_filename

    function_refs
    function_exists
  );
    #children
    #recursive_children

  our %EXPORT_TAGS = ( ALL => [ @EXPORT_OK, @EXPORT ] );

  foreach my $meth (@EXPORT, @EXPORT_OK) {
      my $sub = Class::Inspector->can($meth);
      no strict 'refs';
      *{$meth} = sub {&$sub('Class::Inspector', @_)};
  }

}

1;

=head1 SYNOPSIS

  use Class::Inspector::Functions;
  # Class::Inspector provides a non-polluting,
  # method based interface!
  
  # Is a class installed and/or loaded
  installed( 'Foo::Class' );
  loaded( 'Foo::Class' );
  
  # Filename related information
  filename( 'Foo::Class' );
  resolved_filename( 'Foo::Class' );
  
  # Get subroutine related information
  functions( 'Foo::Class' );
  function_refs( 'Foo::Class' );
  function_exists( 'Foo::Class', 'bar' );
  methods( 'Foo::Class', 'full', 'public' );
  
  # Find all loaded subclasses or something
  subclasses( 'Foo::Class' );

=head1 DESCRIPTION

Class::Inspector::Functions is a function based interface of
L<Class::Inspector>. For a thorough documentation of the available
functions, please check the manual for the main module.

=head2 Exports

The following functions are exported by default.

  installed
  loaded
  filename
  functions
  methods
  subclasses

The following functions are exported only by request.

  resolved_filename
  loaded_filename
  function_refs
  function_exists

All the functions may be imported using the C<:ALL> tag.

=head1 SEE ALSO

L<Class::Handle>, L<Class::Inspector>

=cut
