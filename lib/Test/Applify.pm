package Test::Applify;

use strict;
use warnings;
use Carp 'croak';
use Exporter 'import';
use File::Spec ();
use File::Temp ();
use IO::String ();
use Test::More ();

our @EXPORT_OK = ('applify_ok', 'applify_subcommands_ok');
our $VERSION = '0.06';
our $exited = 0;

sub app {
  @_ == 2 and $_[0]->{app} = $_[1];
  $_[0]->{app};
}

sub applify_ok {
  my $code = shift;
  my $args = shift;
  my $desc = shift || 'applify_ok';
  my $self = __PACKAGE__->new();
  my $dir  = File::Temp->newdir(TEMPLATE => 'test-applify-XXXXX',
                                DIR => $ENV{TMPDIR} || File::Spec->tmpdir);
  my $fh   = File::Temp->new(DIR => $dir, SUFFIX => '.pl');
  my $file = $fh->filename;
  ($fh->syswrite($code) // -1) == length $code
    or croak qq{Can't write to file "$file": $!};

  my $app = $self->_build_code($file, @$args);

  # _build_code does this?
  $self->_test('ok', ref($app), "$desc (compilation)");

  return $app;
}

sub applify_subcommands_ok {
  my $code = shift;
  my $desc = shift || 'applify_subcommands_ok';

  my $app  = applify_ok($code, [], $desc);
  my @apps = $app;
  my $self = __PACKAGE__->new();
  my @cmds = sort keys %{$app->_script->{subcommands}||{}};
  $self->_test('ok', scalar(@cmds), 'has subcommands');

  foreach my $cmd(@cmds) {
    my $cmd_app = applify_ok($code, [$cmd], "$desc - $cmd");
    push @apps, $cmd_app
      if $self->_test('is', $cmd_app->_script->subcommand, $cmd, "$desc - create");
  }
  $self->_test('is', scalar(@apps), scalar(@cmds) + 1, "$desc - created all");

  return \@apps;
}

sub app_script {
  shift->app->_script;
}

sub app_instance {
  my ($self, $name) = (shift, @_);
  $name = shift if ($name and $name =~ /^\w+/); # no change to specialisation now
  local @ARGV = @_;
  return ($self->app_script->app)[0];
}

sub can_ok {
  my $self = shift;
  $self->_test('can_ok', $self->app, @_);
  return $self;
}

sub documentation_ok {
  my $self = shift;
  my $like = shift;
  my $doc  = $self->app_script->documentation;
  $self->_test('ok', $doc, 'has documentation');
  $self->_test('like', $doc, $like, "documentation not like $like") if $like;
  return $self;
}

sub extends_ok {
    my $self = shift;
    $self->_test('isa_ok', $self->app, $_[0], $_[1] || 'application class');
    return $self;
}

sub help_ok {
  my $self = shift;
  my $like = shift || qr/help/;
  local (*STDOUT, *STDERR);
  my ($stdout, $stderr) = ('', '');
  open STDOUT, '>', \$stdout;
  open STDERR, '>', \$stderr;
  $self->app_script->print_help();
  $self->_test('like', $stdout, qr/^usage:/mi, 'has usage string');
  $self->_test('like', $stdout, qr/\-\-help/, 'has help');
  $self->_test('is', $stderr, '', 'no stderr');
  $self->_test('like', $stdout, $like, "help not like $like");
  return $self;
}

sub is_option {
  my $self = shift;
  my $option = $self->app_script->_attr_to_option(shift);
  my @opt = (
    grep { $_ eq $option }
    map  { $self->app_script->_attr_to_option($_->{name}) }
    @{ $self->app_script->options }
  );
  $self->_test('ok', @opt == 1, "--$option is an option");
  return $self;
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
  $self->_test('ok', @opt == 1, "--$option is a required option");
  return $self;
}

sub new {
  my $class = shift;
  my $self  = bless {}, ref $class || $class || __PACKAGE__;
  return $self unless my $app = shift;
  $self->app(ref $app ? $app : $self->_build_code($self->_filename($app)->_filename, @_));
  return $self;
}

sub run_instance_ok {
    my $self = shift;
    my $instance = shift;

    $self->_test('ok', $instance, 'pass run_instance_ok return from app_instance');
    $self->_test('like', ref($instance), qr/^Applify\:\:/, 'application class');
    $self->_test('can_ok', $instance, '_script');

    my ($stdout, $stderr) = ('', '');
    #local (*STDOUT, *STDERR);
    #open STDOUT, '>', \$stdout;
    #open STDERR, '>', \$stderr;
    # different approach to help_ok
    tie *STDOUT, 'IO::String', \$stdout;
    tie *STDERR, 'IO::String', \$stderr;

    $exited = 0;
    my $retval = eval { $instance->run(@_) };

    untie *STDOUT;
    untie *STDERR;

    return ($retval, $stdout || $@, $@ || $stderr, $exited);
}

sub run_ok {
    my ($self, $app, @extra) = (shift);
    {
      local @ARGV = @_;
      $app = ($self->app_script->app)[0];
      @extra = @ARGV;
    }
    $self->run_instance_ok($app, @extra);
}


sub subcommand_ok {
  my $self = shift;
  my $exp  = shift;
  my $obs  = $self->app_script->subcommand;
  $self->_test('is', $obs, $exp, 'subcommand is correct');
  return $self;
}

sub version_ok {
  my $self = shift;
  my $exp  = shift;
  my $version = $self->app_script->version;
  $self->_test('is', $version, $exp, 'version correct');
  return $self;
}

sub _build_code {
  my ($self, $name) = (shift, shift);
  my ($app, %seen);
  (my $ext = $name) =~ s/(\.pl)?$/.pl/i;
  foreach my $file (grep { not $seen{lc $_}++ }
                    grep { -e $_ and -r _ } $name, $ext) {
    {
        ## no critic(Modules::ProhibitMultiplePackages)
      eval {
        package
          Test::Applify::Container; # do not index
        require Applify;
        no strict 'refs';
        no warnings 'redefine';
        my $code = Applify->can('app');
        my $tmp; ## copy - help recovering bad code.
        # like a BEGIN block https://stackoverflow.com/a/25376064
        # "bakes" it into do().
        *CORE::GLOBAL::exit = sub (;$) {
            $exited = 1;
        };
        local *{"Applify\::app"} = sub (&) {
          ## do not run the app - even if user authored incorrect code.
          ($tmp) = $code->(@_); ## force array context
          return $tmp;
        };
        local @ARGV = @_; # support subcommand
        $app = do $file;
        # no warnings 'once' and https://stackoverflow.com/a/25376064
        #*CORE::GLOBAL::exit = *CORE::exit;

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
      $self->_filename($file);
    }
  }
  die $@ if $@;
  die "Applify app not created ($!)\n" if not defined $app;
  $self->_test('ok', ref($app), "do succeeded $name");
  $self->_test('can_ok', $app, '_script');
  $self->_test('isa_ok', $app->_script, 'Applify', 'type');
  return $app;
}

sub _filename {
  return $_[0]->{_filename} if @_ == 1;
  $_[0]->{_filename} = $_[1];
  return $_[0];
}

sub _test {
  my ($self, $name, @args) = @_;
  local $Test::Builder::Level = $Test::Builder::Level + 2;
  return !!Test::More->can($name)->(@args);
}

1;

=head1 NAME

Test::Applify - Testing Applify scripts

=begin html

<!-- Travis-CI.org -->
<a href="https://travis-ci.org/kiwiroy/perl5-Test-Applify">
  <img src="https://travis-ci.org/kiwiroy/perl5-Test-Applify.svg?branch=master"
       alt="Build Status">
</a>
<!-- Coveralls.io -->
<a href="https://coveralls.io/github/kiwiroy/perl5-Test-Applify?branch=master">
  <img src="https://coveralls.io/repos/github/kiwiroy/perl5-Test-Applify/badge.svg?branch=master"
       alt="Coverage Status">
</a>
<!-- Kritika.io -->
<a href="https://kritika.io/users/kiwiroy/repos/9259367477562624/heads/master/">
  <img src="https://kritika.io/users/kiwiroy/repos/9259367477562624/heads/master/status.svg"
       alt="Kritika Analysis Status" />
</a>
<!-- CPAN version -->
<a href="https://badge.fury.io/pl/Test-Applify">
  <img src="https://badge.fury.io/pl/Test-Applify.svg" alt="CPAN version" height="18">
</a>

=end html

=head1 SYNOPSIS

  use Test::More;
  use Test::Applify 'applify_ok';

  my $t = Test::Applify->new('./bin/app.pl');
  $t->help_ok(qr/basic/)
    ->documentation_ok
    ->version_ok('1.0.999');
  $t->is_option($_) for qw{mode input};
  $t->is_required_option($_) for qw{input};

  my $app1 = $t->app_instance(qw{-input strings.txt});
  is $app1->mode, 'basic', 'basic mode is default';

  my $app2 = $t->app_instance(qw{-mode expert -input strings.txt});
  is $app2->mode, 'expert', 'expert mode enabled';
  is $app2->input, 'strings.txt', 'reading strings.txt';
  $t->run_instance_ok($app2);

  my $inlineapp = applify_ok("use Applify; app { print 'hello world!'; 0;};");
  $t = Test::Applify->new($inlineapp);

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

=head1 EXPORTED FUNCTIONS

=head2 applify_ok

  use Test::Applify 'applify_ok';
  my $inlineapp = applify_ok("use Applify; app { print 'Hello world!'; 0;};");
  my $t = Test::Applify->new($inlineapp);

  my $helloapp = applify_ok("use Applify; app { print 'Hello $_[1]!'; 0;};",
                            \@ARGV, 'hello app');
  my $t = Test::Applify->new($helloapp);

Utility function that wraps L<perlfunc/eval> and runs the same tests as L</new>.

This function must be imported.

=head2 applify_subcommands_ok

  use Test::Applify 'applify_subcommands_ok';
  my $subcmds = applify_subcommands_ok($code);
  foreach my $app(@$subcmds){
    Test::Applify->new($app)->help_ok
      ->documentation_ok
      ->version_ok('1')
      ->is_required_option('global_option')
  }

Like L</applify_ok>, but creates each of the subcommands and return in an array
reference.

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
  is $safe->mode, 'safe', 'will run in safe mode';
  my $risky = $t->app_instance();
  is $risky->mode, 'expert', 'expert mode is the default';

Create an instance of the application class, which will be the contents of the
L<Applify> script created. The array passed will be turned into C<@ARGV> as if
those options had been passed on the command line.

=head2 can_ok

  $t->can_ok(qw{mode input});

Test for the presence of methods that the script has.

=head2 documentation_ok

  $t->documentation_ok;

Test the documentation.

=head2 extends_ok

  $t->extends_ok('Parent::Class');
  $t->extends_ok('Parent::Class', 'object name');

Test the inheritance.

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

  my $t = Test::Applify->new('./script.pl');
  # instance for the 'list' subcommand
  my $t = Test::Applify->new('./script.pl', 'list');

Instantiate a new test instance for the supplied script name.

=head2 run_instance_ok

  my $t = Test::Applify->new('./script.pl');
  my $app = $t->app_instance(qw{-mode expert});
  is $app->mode, 'expert', 'everyone is an expert';
  my ($retval, $stdout, $stderr, $exited) = $t->run_instance_ok($app);

Call C<run> on the L<Applify> application class instance
(execute the C<app {}> block). Returns a list of scalars which are:

=over 4

=item retval - the return value of the C<app> block

This is C<undef> when L<perlfunc/die> called

=item stdout - the content that was printed to C<STDOUT> during the run

=item stderr - L<perlvar/"$@"> or the content that was printed to C<STDERR> during the run

=item exit - whether the code exited

=back

=head2 run_ok

  my $t = Test::Applify->new('./script.pl');
  my ($exit, $stdout, $stderr, $retval) = $t->run_ok(qw{-mode expert});

Same as L</run_instance_ok>, but less code.

=head2 subcommand_ok

  my $subcommand = $t->subcommand_ok('list');

Test that the subcommand computed from C<@ARGV> matches the supplied subcommand.

=head2 version_ok

  $t->version_ok('1.0.999');

Test that the version matches the supplied version.

=cut
