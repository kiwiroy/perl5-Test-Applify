use strict;
use warnings;
use Test::More;
use Test::Applify;

my $t = Test::Applify->new('t/file.pl');
can_ok $t, qw{app app_script app_instance can_ok documentation_ok help_ok};
can_ok $t, qw{is_option is_required_option version_ok};

isa_ok $t->app_script, 'Applify', 'type is Applify';

$t->can_ok(qw{mode input log});
$t->documentation_ok;
my $help = $t->help_ok;
like $help, qr/options/, 'synopsis included';

$t->is_option($_) for qw{mode input};
$t->is_required_option($_) for qw{input};
$t->version_ok('1.2.999');

## app instance
my $inst = $t->app_instance;
is $inst->mode, 'basic', 'default';
is $inst->input, undef, 'default';

## with arguments
$inst = $t->app_instance(qw{--mode expert --input test.txt});
is $inst->mode, 'expert', 'set';
is $inst->input, 'test.txt', 'also set';

##
## Test other initialisation states
##

## script with syntax errors
eval { Test::Applify->new('t/syntax-error-1.pl'); };
like $@, qr[syntax error at t/syntax\-error\-1\.pl], 'syntax error';

## script with syntax errors
eval { Test::Applify->new('t/syntax-error-2.pl'); };
like $@, qr[Can't locate WhiteSpace\.pm in \@INC], 'syntax error';

## script that does not exist
eval { Test::Applify->new('t/not-existing.pl'); };
like $@, qr[Applify app not created], 'app not defined';
like $@, qr[\(No such file or directory\)], 'no such file';

## script that has an expression evaluated after app() is.
$t = Test::Applify->new('t/coding-error-1.pl');
is $t->app_instance->some_method, 'something', 'recovered';

## script that has definitions after app()
$t = Test::Applify->new('t/coding-error-2.pl');
is $t->app_instance->some_method, 'something', 'recovered again';

eval { Test::Applify->new('t/coding-error-3.pl'); };
like $@, qr[coding error in], 'coding error - no app';


done_testing;
