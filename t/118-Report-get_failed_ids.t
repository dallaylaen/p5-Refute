#!/usr/bin/env perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Report;

my $rep = Refute::Report->new;

$rep->not_ok( 0 ); # ok
$rep->not_ok( 1 );
$rep->not_ok( 0 );
$rep->not_ok( [ "foo", "isn't", "bar" ] );

is_deeply [ $rep->get_failed_ids ], [ 2, 4 ], "Failed ids as expected";

done_testing;
