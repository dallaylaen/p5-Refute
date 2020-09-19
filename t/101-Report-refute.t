#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Report;

my $c = Refute::Report->new;

ok $c->is_passing, "passing: empty = ok";
is $c->get_count, 0, "0 tests run";
is $c->get_fail_count, 0, "0 of them failed";
is_deeply [$c->get_tests], [], "get_tests works";

ok $c->not_ok( 0, "right" ), "not_ok(false) yelds true";
ok $c->is_passing, "still passing";
ok !$c->not_ok( "foobared", "wrong" ), "not_ok(false) yelds true";
ok !$c->is_passing, "not passing now";
is $c->get_count, 2, "2 tests now";
is $c->get_fail_count, 1, "1 of them failed";
is_deeply [$c->get_tests], [1..2], "get_tests works";

like $c->get_tap, qr/^ok 1 - right\nnot ok 2 - wrong\n# .*foobared.*\n$/s,
    "get_tap looks like tap";

$c->done_testing;
like $c->get_tap, qr/\n1..2(\n|$)/, "Plan present";

eval {
    $c->done_testing;
};

like $@, qr/Refute::Report->done_testing.*done_testing.*no more/
    , "done_testing locks execution log";

done_testing;
