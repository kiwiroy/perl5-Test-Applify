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
  test => {TESTS => 't/*.t'}
);
