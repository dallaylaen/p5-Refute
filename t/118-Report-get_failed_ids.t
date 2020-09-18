#!/usr/bin/env perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Core::Report;

my $rep = Refute::Core::Report->new;

$rep->refute( 0 ); # ok
$rep->refute( 1 );
$rep->refute( 0 );
$rep->refute( [ "foo", "isn't", "bar" ] );

is_deeply [ $rep->get_failed_ids ], [ 2, 4 ], "Failed ids as expected";

done_testing;
