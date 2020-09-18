#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Refute::Core::Report;

my $pass = Refute::Core::Report->new->do_run( sub {
    $_[0]->ok(1);
});
my $fail = Refute::Core::Report->new->do_run( sub {
    $_[0]->ok(0);
});

my $main = Refute::Core::Report->new;

$main->subcontract( "this passed" => $pass );
$main->subcontract( "this failed" => $fail );
$main->done_testing;

is( $main->get_sign, "t1Nd", "Subcontracts recorded correctly" );
# TODO check actual data inside

done_testing;
