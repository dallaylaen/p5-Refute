#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Refute::Report;

my $pass = Refute::Report->new->do_run( sub {
    $_[0]->ok(1);
});
my $fail = Refute::Report->new->do_run( sub {
    $_[0]->ok(0);
});

my $main = Refute::Report->new;

$main->subcontract( "this passed" => $pass );
$main->subcontract( "this failed" => $fail );
$main->done_testing;

is( $main->get_sign, "t1Nd", "Subcontracts recorded correctly" );
# TODO check actual data inside

done_testing;
