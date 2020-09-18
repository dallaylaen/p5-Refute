#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;
BEGIN{
    $ENV{NDEBUG} = "Some weird reason";
};

use Refute {};

my $report = try_refute {
    not_ok [ 42, 137 ], "Life is fine";
};

ok $report->is_passing, "Report still passing though it shouldn't";

like $report->get_tap, qr/# SKIP\b.*\bSome weird reason/, "Reason preserved";

done_testing;
