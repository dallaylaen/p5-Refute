#!/usr/bin/env perl

use strict;
use warnings;
use Refute ":core";

use Test::More;

my $fail = refute_and_report {
    package T;
    use Refute qw(:all);
    plan tests => 2;
    ok 1;
};

is $fail->get_sign, 't1E', "Contract failed with 1 passing test"
    or diag "<REPORT>\n", $fail->get_tap, "</REPORT>";

is $fail->get_error, "Looks like you planned 2 tests but ran 1",
    "Error as expected";

my $pass = refute_and_report {
    package T;
    use Refute qw(:all);
    plan tests => 2;
    ok 1;
    ok 2;
};

is $pass->get_sign, 't2d', "Contract passes with correct plan";

like $pass->get_tap, qr/^1..2/s, "Plan is at the beginning";

done_testing;
