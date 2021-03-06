#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More tests => 2;

use Refute::Errors;

{
    package T;
    use Refute qw(:all), { on_fail => 'carp' };
};

warns_like {
    package T;
    try_refute {
        not_ok 1, "This shouldn't be output";
    };
} [ qr/not ok 1.*1..1.*[Cc]ontract failed/s ], "Warning as expected";

warns_like {
    package T;
    try_refute {
        not_ok 0, "This shouldn't be output";
    };
} [], "Warning as expected";

