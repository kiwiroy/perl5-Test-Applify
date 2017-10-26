use 5.010001;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Test::Applify',
  VERSION_FROM => 'lib/Test/Applify.pm',
  ABSTRACT     => 'Testing framework for Applify',
  AUTHOR       => 'Roy Storey <kiwiroy@cpan.org>',
  PREREQ_PM    => { Applify => '0.12' },
  EXE_FILES    => [qw{}],
  META_MERGE   => {
    resources => {
      bugtracker => 'https://github.com/kiwiroy/perl5-Test-Applify/issues',
      homepage   => 'https://github.com/kiwiroy/perl5-Test-Applify',
      repository => 'https://github.com/kiwiroy/perl5-Test-Applify.git',
    },
  },
  BUILD_REQUIRES => {'Test::More' => '0.90'},
  test => {TESTS => 't/*.t'}
);
