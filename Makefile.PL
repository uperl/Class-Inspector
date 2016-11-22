use if $INC[-1] ne '.', 'lib', '.';
use inc::Module::Install::DSL 1.06;

all_from      lib/Class/Inspector.pm
requires      if 0
requires      File::Spec 0.80
test_requires Test::More 0.47
