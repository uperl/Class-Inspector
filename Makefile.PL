use inc::Module::Install 0.75;

all_from      'lib/Class/Inspector.pm';
requires      'File::Spec' => '0.80';
test_requires 'Test::More' => '0.47';

WriteAll;
