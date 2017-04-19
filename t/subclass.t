package Test::Applify::Subclass;
use strict;
use warnings;

use base qw{Test::Applify};

sub new {
  my $pkg = shift;
  my $self = $pkg->SUPER::new(@_);
  return $self;
}

package main;
use strict;
use warnings;
use Test::More;

my $n = new_ok('Test::Applify::Subclass');
$n->new;
done_testing;
