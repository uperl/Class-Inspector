#!/usr/bin/perl

# Unit testing for Class::Inspector

# Do all the tests on ourself, where possible, as we know we will be loaded.

use strict;
BEGIN {
  $|  = 1;
        $^W = 1;
}

use Test::More;
use Class::Inspector ();
unless ( $^O eq 'MSWin32' ) {
  plan( skip_all => 'Only applicable Win32' );
  exit(0);
}
plan( tests => 1 );





#####################################################################
# Make sure a Unix path is converted correctly

my $inc   = 'C:/foo/bar.pm';
my $local = Class::Inspector->_inc_to_local($inc);
is( $local, 'C:\foo\bar.pm', '->_inc_to_local ok' );
