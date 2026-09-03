package Class::Inspector::Functions;

use 5.006;
# We don't want to use strict refs anywhere in this module, since we do a
# lot of things in here that aren't strict refs friendly.
use strict qw{vars subs};
use warnings;
use File::Spec ();
use Exporter   ();
use base qw( Exporter );

# ABSTRACT: Get information about a class and its structure
# VERSION

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
L<Class::Inspector>. This is the module in which the actual work is
implemented; the class methods on L<Class::Inspector> are thin wrappers
around the functions defined here. For a thorough documentation of the
available functionality, please check the manual for the main module.

=cut

# If Unicode is available, enable it so that the
# pattern matches below match unicode method names.
# We can safely ignore any failure here.
BEGIN {
  local $@;
  eval {
    require utf8;
    utf8->import;
  };
}

# Predefine some regexs
our $RE_IDENTIFIER = qr/\A[^\W\d]\w*\z/s;
our $RE_CLASS      = qr/\A[^\W\d]\w*(?:(?:\'|::)\w+)*\z/s;

# Are we on something Unix-like?
our $UNIX  = !! ( $File::Spec::ISA[0] eq 'File::Spec::Unix'  );

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

}




#####################################################################
# Basic Functions

sub _resolved_inc_handler {
  my $filename = _inc_filename(shift) or return undef;

  foreach my $inc ( @INC ) {
    my $ref = ref $inc;
    if($ref eq 'CODE') {
      my @ret = $inc->($inc, $filename);
      if(@ret == 1 && ! defined $ret[0]) {
        # do nothing.
      } elsif(@ret) {
        return 1;
      }
    }
    elsif($ref eq 'ARRAY' && ref($inc->[0]) eq 'CODE') {
      my @ret = $inc->[0]->($inc, $filename);
      if(@ret) {
        return 1;
      }
    }
    elsif($ref && eval { $inc->can('INC') }) {
      my @ret = $inc->INC($filename);
      if(@ret) {
        return 1;
      }
    }
  }

  '';
}

sub installed {
  my $name = shift;
  !! (loaded_filename($name) or resolved_filename($name) or _resolved_inc_handler($name));
}

sub loaded {
  my $name = _class(shift) or return undef;
  _loaded($name);
}

sub _loaded {
  my $name = shift;

  # Handle by far the two most common cases
  # This is very fast and handles 99% of cases.
  return 1 if defined ${"${name}::VERSION"};
  return 1 if @{"${name}::ISA"};

  # Are there any symbol table entries other than other namespaces
  foreach ( keys %{"${name}::"} ) {
    next if substr($_, -2, 2) eq '::';
    return 1 if defined &{"${name}::$_"};
  }

  # No functions, and it doesn't have a version, and isn't anything.
  # As an absolute last resort, check for an entry in %INC
  my $filename = _inc_filename($name);
  return 1 if defined $INC{$filename};

  '';
}

sub filename {
  my $name = _class(shift) or return undef;
  File::Spec->catfile( split /(?:\'|::)/, $name ) . '.pm';
}

sub resolved_filename {
  my $filename  = _inc_filename(shift) or return undef;
  my @try_first = @_;

  # Look through the @INC path to find the file
  foreach ( @try_first, @INC ) {
    my $full = "$_/$filename";
    next unless -e $full;
    return $UNIX ? $full : _inc_to_local($full);
  }

  # File not found
  '';
}

sub loaded_filename {
  my $filename = _inc_filename(shift);
  $UNIX ? $INC{$filename} : _inc_to_local($INC{$filename});
}




#####################################################################
# Sub Related Functions

sub functions {
  my $name = _class(shift) or return undef;
  return undef unless loaded( $name );

  # Get all the CODE symbol table entries
  my @functions = sort grep { /$RE_IDENTIFIER/o }
    grep { defined &{"${name}::$_"} }
    keys %{"${name}::"};
  \@functions;
}

sub function_refs {
  my $name = _class(shift) or return undef;
  return undef unless loaded( $name );

  # Get all the CODE symbol table entries, but return
  # the actual CODE refs this time.
  my @functions = map { \&{"${name}::$_"} }
    sort grep { /$RE_IDENTIFIER/o }
    grep { defined &{"${name}::$_"} }
    keys %{"${name}::"};
  \@functions;
}

sub function_exists {
  my $name     = _class( shift ) or return undef;
  my $function = shift or return undef;

  # Only works if the class is loaded
  return undef unless loaded( $name );

  # Does the GLOB exist and its CODE part exist
  defined &{"${name}::$function"};
}

sub methods {
  my $name      = _class( shift ) or return undef;
  my @arguments = map { lc $_ } @_;

  # Process the arguments to determine the options
  my %options = ();
  foreach ( @arguments ) {
    if ( $_ eq 'public' ) {
      # Only get public methods
      return undef if $options{private};
      $options{public} = 1;

    } elsif ( $_ eq 'private' ) {
      # Only get private methods
      return undef if $options{public};
      $options{private} = 1;

    } elsif ( $_ eq 'full' ) {
      # Return the full method name
      return undef if $options{expanded};
      $options{full} = 1;

    } elsif ( $_ eq 'expanded' ) {
      # Returns class, method and function ref
      return undef if $options{full};
      $options{expanded} = 1;

    } else {
      # Unknown or unsupported options
      return undef;
    }
  }

  # Only works if the class is loaded
  return undef unless loaded( $name );

  # Get the super path ( not including UNIVERSAL )
  # Rather than using Class::ISA, we'll use an inlined version
  # that implements the same basic algorithm.
  my @path  = ();
  my @queue = ( $name );
  my %seen  = ( $name => 1 );
  while ( my $cl = shift @queue ) {
    push @path, $cl;
    unshift @queue, grep { ! $seen{$_}++ }
      map { s/^::/main::/; s/\'/::/g; $_ } ##  no critic
      map { "$_" }
      ( @{"${cl}::ISA"} );
  }

  # Find and merge the function names across the entire super path.
  # Sort alphabetically and return.
  my %methods = ();
  foreach my $namespace ( @path ) {
    my @functions = grep { ! $methods{$_} }
      grep { /$RE_IDENTIFIER/o }
      grep { defined &{"${namespace}::$_"} }
      keys %{"${namespace}::"};
    foreach ( @functions ) {
      $methods{$_} = $namespace;
    }
  }

  # Filter to public or private methods if needed
  my @methodlist = sort keys %methods;
  @methodlist = grep { ! /^\_/ } @methodlist if $options{public};
  @methodlist = grep {   /^\_/ } @methodlist if $options{private};

  # Return in the correct format
  @methodlist = map { "$methods{$_}::$_" } @methodlist if $options{full};
  @methodlist = map {
    [ "$methods{$_}::$_", $methods{$_}, $_, \&{"$methods{$_}::$_"} ]
    } @methodlist if $options{expanded};

  \@methodlist;
}




#####################################################################
# Search Functions

sub subclasses {
  my $name  = _class( shift ) or return undef;

  # Prepare the search queue
  my @found = ();
  my @queue = grep { $_ ne 'main' } _subnames('');
  while ( @queue ) {
    my $c = shift(@queue); # c for class
    if ( _loaded($c) ) {
      # At least one person has managed to misengineer
      # a situation in which ->isa could die, even if the
      # class is real. Trap these cases and just skip
      # over that (bizarre) class. That would at limit
      # problems with finding subclasses to only the
      # modules that have broken ->isa implementation.
      local $@;
      eval {
        if ( $c->isa($name) ) {
          # Add to the found list, but don't add the class itself
          push @found, $c unless $c eq $name;
        }
      };
    }

    # Add any child namespaces to the head of the queue.
    # This keeps the queue length shorted, and allows us
    # not to have to do another sort at the end.
    unshift @queue, map { "${c}::$_" } _subnames($c);
  }

  @found ? \@found : '';
}

sub _subnames {
  my ($name) = @_;
  return sort
    grep {  ## no critic
      substr($_, -2, 2, '') eq '::'
      and
      /$RE_IDENTIFIER/o
    }
    keys %{"${name}::"};
}




#####################################################################
# Children Related Functions

# These can go undocumented for now, until I decide if its best to
# just search the children in namespace only, or if I should do it via
# the file system.

# Find all the loaded classes below us
sub children {
  my $name = _class(shift) or return ();

  # Find all the Foo:: elements in our symbol table
  no strict 'refs';
  map { "${name}::$_" } sort grep { s/::$// } keys %{"${name}::"};  ## no critic
}

# As above, but recursively
sub recursive_children {
  my $name     = _class(shift) or return ();
  my @children = ( $name );

  # Do the search using a nicer, more memory efficient
  # variant of actual recursion.
  my $i = 0;
  no strict 'refs';
  while ( my $namespace = $children[$i++] ) {
    push @children, map { "${namespace}::$_" }
      grep { ! /^::/ } # Ignore things like ::ISA::CACHE::
      grep { s/::$// }  ## no critic
      keys %{"${namespace}::"};
  }

  sort @children;
}




#####################################################################
# Private Functions

# Checks and expands ( if needed ) a class name
sub _class {
  my $name = shift or return '';

  # Handle main shorthand
  return 'main' if $name eq '::';
  $name =~ s/\A::/main::/;

  # Check the class name is valid
  $name =~ /$RE_CLASS/o ? $name : '';
}

# Create a INC-specific filename, which always uses '/'
# regardless of platform.
sub _inc_filename {
  my $name = _class(shift) or return undef;
  join( '/', split /(?:\'|::)/, $name ) . '.pm';
}

# Convert INC-specific file name to local file name
sub _inc_to_local {
  # Shortcut in the Unix case
  return $_[0] if $UNIX;

  # On other places, we have to deal with an unusual path that might look
  # like C:/foo/bar.pm which doesn't fit ANY normal pattern.
  # Putting it through splitpath/dir and back again seems to normalise
  # it to a reasonable amount.
  my $inc_name           = shift or return undef;
  my ($vol, $dir, $file) = File::Spec->splitpath( $inc_name );
  $dir = File::Spec->catdir( File::Spec->splitdir( $dir || "" ) );
  File::Spec->catpath( $vol, $dir, $file || "" );
}

# Class::Inspector provides the classic method-based interface as thin
# wrappers around the functions implemented above.
require Class::Inspector;

1;

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
