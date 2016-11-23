use if $INC[-1] ne '.', 'lib', '.';
use inc::Module::Install 1.06;

author        'Adam Kennedy <adamk@cpan.org>';
author        'Graham Ollis <plicease@cpan.org>';
all_from      'lib/Class/Inspector.pm';
configure_requires 'if' => 0;
requires      'File::Spec' => '0.80';
test_requires 'Test::More' => '0.47';
homepage      'https://metacpan.org/pod/Class::Inspector';
bugtracker    'https://github.com/plicease/Class-Inspector/issues';
repository    'git://github.com/plicease/FFI-Platypus.git';

WriteAll();
