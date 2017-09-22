package Test::Applify;

use strict;
use warnings;
use Test::More ();

our $VERSION = '0.01';

sub app {
  @_ == 2 and $_[0]->{app} = $_[1];
  $_[0]->{app};
}

sub app_script {
  shift->app->_script;
}

sub app_instance {
  my $self = shift;
  local @ARGV = @_;
  return $self->app_script->app;
}

sub can_ok {
  my $self = shift;
  $self->_test('can_ok', $self->app, @_);
}

sub documentation_ok {
  my $self = shift;
  my $doc  = $self->app_script->documentation;
  $self->_test('ok', $doc, 'has documentation');
  return $doc;
}

sub help_ok {
  my $self = shift;
  local *STDOUT;
  local *STDERR;
  my $stdout = '';
  my $stderr = '';
  open STDOUT, '>', \$stdout;
  open STDERR, '>', \$stderr;
  $self->app_script->print_help();
  $self->_test('like', $stdout, qr/^usage:/mi, 'has usage string');
  $self->_test('like', $stdout, qr/\-\-help/, 'has help');
  $self->_test('is', $stderr, '', 'no stderr');
  return $stdout;
}

sub is_option {
  my $self = shift;
  my $option = $self->app_script->_attr_to_option(shift);
  my @opt = (
    grep { $_ eq $option }
    map  { $self->app_script->_attr_to_option($_->{name}) }
    @{ $self->app_script->options }
  );
  return $self->_test('ok', @opt == 1, "--$option is an option");
}

sub is_required_option {
  my $self = shift;
  my $option = $self->app_script->_attr_to_option(shift);
  my @opt = (
    grep { $_ eq $option}
    map  { $self->app_script->_attr_to_option($_->{name}) }
    grep { $_->{required} }
    @{ $self->app_script->options }
  );
  return $self->_test('ok', @opt == 1, "--$option is a required option");
}

sub new {
  my $class = shift;
  my $self  = bless {}, ref $class || $class || __PACKAGE__;
  return $self unless my $app = shift;
  $self->app(ref $app ? $app : $self->_build_code($app));
  return $self;
}

sub version_ok {
  my $self = shift;
  my $exp  = shift;
  my $version = $self->app_script->version;
  $self->_test('is', $version, $exp, 'version correct');
  return $version;
}

sub _build_code {
  my ($self, $name) = @_;
  my ($app, %seen);
  foreach my $file (grep { not $seen{$_}++ }
                    grep { -e $_ and -r _ } $name, $name =~ s/(\.pl)?$/.pl/ir) {
    {
      eval {
        package Test::Applify::Container;
        require Applify;
        no strict 'refs';
        no warnings 'redefine';
        my $code = Applify->can('app');
        my $tmp; ## copy - help recovering bad code.
        local *{"Applify\::app"} = sub (&) {
          ## do not run the app - even if user authored incorrect code.
          ($tmp) = $code->(@_); ## force array context
          return $tmp;
        };
        $app = do $file;

        if ($@) {
          ## script didn't compile - syntax error, missing modules, etc...
          die $@;
        } elsif (! defined $tmp){
          die "coding error in $file - app must be called\n";
        } elsif (!(ref($app) && $app->can('_script') && ref($app->_script) eq 'Applify')) {
          $app = $tmp;
          warn "coding error in $file - app must be the last function called\n";
        }
      };
    }
  }
  die $@ if $@;
  die "Applify app not created ($!)\n" if not defined $app;
  $self->_test('ok', ref($app), "do succeeded $name");
  $self->_test('can_ok', $app, '_script');
  $self->_test('isa_ok', $app->_script, 'Applify', 'type');
  return $app;
}

sub _test {
  my ($self, $name, @args) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 2;
  return !!Test::More->can($name)->(@args);
}

1;

=head1 NAME

Test::Applify - Testing Applify scripts

=for html <a href="https://travis-ci.org/kiwiroy/perl5-Test-Applify"><img src="https://travis-ci.org/kiwiroy/perl5-Test-Applify.svg?branch=master" alt="Build Status"></a>

=for html <a href="https://coveralls.io/github/kiwiroy/perl5-Test-Applify?branch=master"><img src="https://coveralls.io/repos/github/kiwiroy/perl5-Test-Applify/badge.svg?branch=master" alt="Coverage Status"></a>

=head1 SYNOPSIS

  use Test::More;
  use Test::Applify;

  my $t = Test::Applify->new('./bin/app.pl');
  my $help = $t->help_ok;
  like $help, qr/basic/, 'help mentions basic mode';
  $t->documentation_ok;
  $t->version_ok('1.0.999');
  $t->is_option($_) for qw{mode input};
  $t->is_required_option($_) for qw{input};

  my $app1 = $t->app_instance(qw{-input strings.txt});
  is $app1->mode, 'basic', 'basic mode is default';

  my $app2 = $t->app_instance(qw{-mode expert -input strings.txt});
  is $app2->mode, 'expert', 'expert mode enabled';
  is $app2->input, 'strings.txt', 'reading strings.txt';

=head1 DESCRIPTION

L<Test::Applify> is a test agent to be used with L<Test::More> to test
L<Applify> scripts. To run your tests use L<prove>.

  $ prove -l -v t

Avoid testing the Applify code for correctness, it has its own test suite.
Instead, test for consistency of option behaviour, defaults and requiredness,
the script is compiled and that attributes and methods of the script behave with
different inputs.

The aim is to remove repetition of multiple blocks to retrieve instances and
checks for success of C<do>.

  my $app = do 'bin/app.pl'; ## check $@ and return value
  {
    local @ARGV = qw{...};
    my $instance = $app->_script->app;
    # more tests.
  }

=head1 METHODS

=head2 app

  my $t   = Test::Applify->new('./bin/app.pl');
  my $app = $t->app;

Access to the application.

B<N.B.> The removal of C<.> from C<@INC> requires relative paths to start with
C<./>. See link for further information L<https://goo.gl/eJ6k9E>

=head2 app_script

  my $script = $t->app_script;
  isa_ok $script, 'Applify', 'the Applify object';

Access to the Applify object.

=head2 app_instance

  my $safe  = $t->app_instance(qw{-opt value -mode safe});
  my $risky = $t->app_instance();
  is $risky->mode, 'expert', 'expert mode is the default';

=head2 can_ok

  $t->can_ok(qw{mode input});

Test for the presence of methods that the script has.

=head2 documentation_ok

  $t->documentation_ok;

Test the documentation.

=head2 help_ok

  my $help = $t->help_ok;

Test and access the help for the script.

=head2 is_option

  $t->is_option('mode');
  $t->is_option($_) for qw{mode input};

Test for the presence of an option with the supplied name

=head2 is_required_option

  $t->is_required_option('input');

Test that the option is a required option.

=head2 new

  my $t = Test::Applify->new('script.pl');

Instantiate a new test instance for the supplied script name.

=head2 version_ok

  $t->version_ok('1.0.999');

Test that the version matches the supplied version.

=cut
