#!/usr/bin/env perl

# This test checks that TAP generated by Refute::Core::Report
# is exactly as expected.
# This is likely to fail if cosmetic changes are made to formatting,
# and will have to be manually adjusted in such cases.
# On the other hand, refactorings and adding new functions whould not break it.

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
# instantiate before Test::More to avoid autodetect
use Refute {};

# plan in advance to increase probability of abstraction leak detection
use Test::More tests => 10;

# how to read this file:
# each test is an "is"
# is
# try_refute {
#    ... (tests here)
# }->get_tap,
# <<"TEST",
#    ... expected result here
# TEST
# "Test name";

# This line is here to make sure a real "ok" or "diag"
# didn't creep into code under test
my $all_good = uc "if you see this, the test has failed";

is
try_refute {
    # empty test
}->get_tap,
<<"TEST",
1..0
TEST
"No tests run - this is fine";

is
try_refute {
    refute 0, "$all_good";
    refute 0, '';
}->get_tap,
<<"TEST",
ok 1 - $all_good
ok 2
1..2
TEST
"A passing test";

is
try_refute {
    $_[0]->plan( tests => 2 );
    refute 0, "$all_good";
    refute 0, '';
}->get_tap,
<<"TEST",
1..2
ok 1 - $all_good
ok 2
TEST
"A passing test with plan";

is
try_refute {
    refute 0, "$all_good";
    $_[0]->diag("$all_good");
    refute 0, '';
}->get_tap,
<<"TEST",
ok 1 - $all_good
# $all_good
ok 2
1..2
TEST
"A passing test with diag inside";


is
try_refute {
    refute 0, "$all_good";
    subcontract "$all_good" => sub {
        refute 0, "$all_good";
        $_[0]->diag("$all_good");
        $_[0]->diag("Indented as intended");
    };
    refute 0, '';
}->get_tap,
<<"TEST",
ok 1 - $all_good
ok 2 - $all_good (subtest)
    ok 1 - $all_good
    # $all_good
    # Indented as intended
    1..1
ok 3
1..3
TEST
"A passing test with subcontract";

# now failing contracts

is
try_refute {
    refute $all_good, $all_good;
}->get_tap,
<<"TEST",
not ok 1 - $all_good
# $all_good
# Looks like 1 tests out of 1 have failed
1..1
TEST
"A failing contract";

is
try_refute {
    refute [ $all_good, "isn't", 42 ], $all_good;
}->get_tap,
<<"TEST",
not ok 1 - $all_good
# $all_good
# isn't
# 42
# Looks like 1 tests out of 1 have failed
1..1
TEST
"A failing contract, array autounfold";

is
try_refute {
    $_[0]->plan( tests => 3 );
    refute 0, $all_good;
}->get_tap,
<<"TEST",
1..3
ok 1 - $all_good
# Looks like you planned 3 tests but ran 1
TEST
"A failing plan";

is
try_refute {
    $_[0]->plan( tests => 1 );
    refute 0, $all_good;
    die "Foo bared\n";
}->get_tap,
<<"TEST",
1..1
ok 1 - $all_good
# Looks like contract was interrupted by Foo bared
TEST
"Interrupted execution";

is
try_refute {
    $_[0]->plan( tests => 3 );
    refute 0, $all_good;
    subcontract $all_good => sub {
        refute $all_good, $all_good;
    };
    refute 0, '';
}->get_tap,
<<"TEST",
1..3
ok 1 - $all_good
not ok 2 - $all_good (subtest)
    not ok 1 - $all_good
    # $all_good
    # Looks like 1 tests out of 1 have failed
    1..1
ok 3
# Looks like 1 tests out of 3 have failed
TEST
"Failing subcontract";

