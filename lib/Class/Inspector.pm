package Class::Inspector;

use 5.006;
use strict;
use warnings;
use Class::Inspector::Functions ();

# ABSTRACT: Get information about a class and its structure
# VERSION

=head1 SYNOPSIS

  use Class::Inspector;

  # Is a class installed and/or loaded
  Class::Inspector->installed( 'Foo::Class' );
  Class::Inspector->loaded( 'Foo::Class' );

  # Filename related information
  Class::Inspector->filename( 'Foo::Class' );
  Class::Inspector->resolved_filename( 'Foo::Class' );

  # Get subroutine related information
  Class::Inspector->functions( 'Foo::Class' );
  Class::Inspector->function_refs( 'Foo::Class' );
  Class::Inspector->function_exists( 'Foo::Class', 'bar' );
  Class::Inspector->methods( 'Foo::Class', 'full', 'public' );

  # Find all loaded subclasses or something
  Class::Inspector->subclasses( 'Foo::Class' );

=head1 DESCRIPTION

Class::Inspector allows you to get information about a loaded class. Most or
all of this information can be found in other ways, but they aren't always
very friendly, and usually involve a relatively high level of Perl wizardry,
or strange and unusual looking code. Class::Inspector attempts to provide
an easier, more friendly interface to this information.

The actual implementation lives in L<Class::Inspector::Functions>; each of
the class methods below is a thin wrapper that drops the invocant and
forwards to the function of the same name.

=head1 METHODS

=cut

# Backwards compatibility: these used to be defined here.  The canonical
# copies now live in Class::Inspector::Functions.
our $RE_IDENTIFIER = $Class::Inspector::Functions::RE_IDENTIFIER;
our $RE_CLASS      = $Class::Inspector::Functions::RE_CLASS;
our $UNIX          = $Class::Inspector::Functions::UNIX;

# Build a method for every function implemented in
# Class::Inspector::Functions.  Each wrapper simply discards the invocant
# and calls through to the underlying function.
BEGIN {
  my @names = qw(
    installed
    loaded
    filename
    resolved_filename
    loaded_filename
    functions
    function_refs
    function_exists
    methods
    subclasses
    children
    recursive_children
    _class
    _loaded
    _inc_filename
    _inc_to_local
    _resolved_inc_handler
    _subnames
  );

  foreach my $name ( @names ) {
    my $function = Class::Inspector::Functions->can($name)
      or die "Class::Inspector::Functions does not implement $name";
    no strict 'refs';
    *{"Class::Inspector::$name"} = sub {
      shift;
      $function->(@_);
    };
  }
}

#####################################################################
# Basic Methods

=pod

=head2 installed

 my $bool = Class::Inspector->installed($class);

The C<installed> static method tries to determine if a class is installed
on the machine, or at least available to Perl. It does this by wrapping
around C<resolved_filename>.

Returns true if installed/available, false if the class is not installed,
or C<undef> if the class name is invalid.

=head2 loaded

 my $bool = Class::Inspector->loaded($class);

The C<loaded> static method tries to determine if a class is loaded by
looking for symbol table entries.

This method it uses to determine this will work even if the class does not
have its own file, but is contained inside a single file with multiple
classes in it. Even in the case of some sort of run-time loading class
being used, these typically leave some trace in the symbol table, so an
L<Autoload> or L<Class::Autouse>-based class should correctly appear
loaded.

Returns true if the class is loaded, false if not, or C<undef> if the
class name is invalid.

=head2 filename

 my $filename = Class::Inspector->filename($class);

For a given class, returns the base filename for the class. This will NOT
be a fully resolved filename, just the part of the filename BELOW the
C<@INC> entry.

  print Class->filename( 'Foo::Bar' );
  > Foo/Bar.pm

This filename will be returned with the right separator for the local
platform, and should work on all platforms.

Returns the filename on success or C<undef> if the class name is invalid.

=head2 resolved_filename

 my $filename = Class::Inspector->resolved_filename($class);
 my $filename = Class::Inspector->resolved_filename($class, @try_first);

For a given class, the C<resolved_filename> static method returns the fully
resolved filename for a class. That is, the file that the class would be
loaded from.

This is not necessarily the file that the class WAS loaded from, as the
value returned is determined each time it runs, and the C<@INC> include
path may change.

To get the actual file for a loaded class, see the C<loaded_filename>
method.

Returns the filename for the class, or C<undef> if the class name is
invalid.

=head2 loaded_filename

 my $filename = Class::Inspector->loaded_filename($class);

For a given loaded class, the C<loaded_filename> static method determines
(via the C<%INC> hash) the name of the file that it was originally loaded
from.

Returns a resolved file path, or false if the class did not have it's own
file.

=cut

#####################################################################
# Sub Related Methods

=pod

=head2 functions

 my $arrayref = Class::Inspector->functions($class);

For a loaded class, the C<functions> static method returns a list of the
names of all the functions in the classes immediate namespace.

Note that this is not the METHODS of the class, just the functions.

Returns a reference to an array of the function names on success, or C<undef>
if the class name is invalid or the class is not loaded.

=head2 function_refs

 my $arrayref = Class::Inspector->function_refs($class);

For a loaded class, the C<function_refs> static method returns references to
all the functions in the classes immediate namespace.

Note that this is not the METHODS of the class, just the functions.

Returns a reference to an array of C<CODE> refs of the functions on
success, or C<undef> if the class is not loaded.

=head2 function_exists

 my $bool = Class::Inspector->function_exists($class, $functon);

Given a class and function name the C<function_exists> static method will
check to see if the function exists in the class.

Note that this is as a function, not as a method. To see if a method
exists for a class, use the C<can> method for any class or object.

Returns true if the function exists, false if not, or C<undef> if the
class or function name are invalid, or the class is not loaded.

=head2 methods

 my $arrayref = Class::Inspector->methods($class, @options);

For a given class name, the C<methods> static method will returns ALL
the methods available to that class. This includes all methods available
from every class up the class' C<@ISA> tree.

Returns a reference to an array of the names of all the available methods
on success, or C<undef> if the class name is invalid or the class is not
loaded.

A number of options are available to the C<methods> method that will alter
the results returned. These should be listed after the class name, in any
order.

  # Only get public methods
  my $method = Class::Inspector->methods( 'My::Class', 'public' );

=over 4

=item public

The C<public> option will return only 'public' methods, as defined by the Perl
convention of prepending an underscore to any 'private' methods. The C<public>
option will effectively remove any methods that start with an underscore.

=item private

The C<private> options will return only 'private' methods, as defined by the
Perl convention of prepending an underscore to an private methods. The
C<private> option will effectively remove an method that do not start with an
underscore.

B<Note: The C<public> and C<private> options are mutually exclusive>

=item full

C<methods> normally returns just the method name. Supplying the C<full> option
will cause the methods to be returned as the full names. That is, instead of
returning C<[ 'method1', 'method2', 'method3' ]>, you would instead get
C<[ 'Class::method1', 'AnotherClass::method2', 'Class::method3' ]>.

=item expanded

The C<expanded> option will cause a lot more information about method to be
returned. Instead of just the method name, you will instead get an array
reference containing the method name as a single combined name, a la C<full>,
the separate class and method, and a CODE ref to the actual function ( if
available ). Please note that the function reference is not guaranteed to
be available. C<Class::Inspector> is intended at some later time, to work
with modules that have some kind of common run-time loader in place ( e.g
C<Autoloader> or C<Class::Autouse> for example.

The response from C<methods( 'Class', 'expanded' )> would look something like
the following.

  [
    [ 'Class::method1',   'Class',   'method1', \&Class::method1   ],
    [ 'Another::method2', 'Another', 'method2', \&Another::method2 ],
    [ 'Foo::bar',         'Foo',     'bar',     \&Foo::bar         ],
  ]

=back

=cut

#####################################################################
# Search Methods

=pod

=head2 subclasses

 my $arrayref = Class::Inspector->subclasses($class);

The C<subclasses> static method will search then entire namespace (and thus
B<all> currently loaded classes) to find all classes that are subclasses
of the class provided as a the parameter.

The actual test will be done by calling C<isa> on the class as a static
method. (i.e. C<My::Class-E<gt>isa($class)>.

Returns a reference to a list of the loaded classes that match the class
provided, or false is none match, or C<undef> if the class name provided
is invalid.

=cut

1;

=pod

=head1 SEE ALSO

L<Class::Handle>, L<Class::Inspector::Functions>

=cut
