# NAME

Test::Applify - Testing Applify scripts

# SYNOPSIS

    use Test::More;
    use Test::Applify;

    my $t = Test::Applify->new('bin/app.pl');
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

# DESCRIPTION

[Test::Applify](https://metacpan.org/pod/Test::Applify) is a test agent to be used with [Test::More](https://metacpan.org/pod/Test::More) to test
[Applify](https://metacpan.org/pod/Applify) scripts. To run your tests use [prove](https://metacpan.org/pod/prove).

    $ prove -l -v t

Avoid testing the Applify code for correctness, it has its own test suite.
Instead, test for consistency of option behaviour, defaults and requiredness,
the script is compiled and that attributes and methods of the script behave with
different inputs.

The aim is to remove repetition of multiple blocks to retrieve instances and
checks for success of `do`.

    my $app = do 'bin/app.pl'; ## check $@ and return value
    {
      local @ARGV = qw{...};
      my $instance = $app->_script->app;
      # more tests.
    }

# METHODS

## app

    my $t   = Test::Applify->new('bin/app.pl');
    my $app = $t->app;

Access to the application.

## app\_script

    my $script = $t->app_script;
    isa_ok $script, 'Applify', 'the Applify object';

Access to the Applify object.

## app\_instance

    my $safe  = $t->app_instance(qw{-opt value -mode safe});
    my $risky = $t->app_instance();
    is $risky->mode, 'expert', 'expert mode is the default';

## can\_ok

    $t->can_ok(qw{mode input});

Test for the presence of methods that the script has.

## documentation\_ok

    $t->documentation_ok;

Test the documentation.

## help\_ok

    my $help = $t->help_ok;

Test and access the help for the script.

## is\_option

    $t->is_option('mode');
    $t->is_option($_) for qw{mode input};

Test for the presence of an option with the supplied name

## is\_required\_option

    $t->is_required_option('input');

Test that the option is a required option.

## new

    my $t = Test::Applify->new('script.pl');

Instantiate a new test instance for the supplied script name.

## version\_ok

    $t->version_ok('1.0.999');

Test that the version matches the supplied version.
