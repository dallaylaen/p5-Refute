#!/usr/bin/env perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };

# Avoid Test::More detection
use Refute::Builder qw(to_scalar);
use Refute::Common qw(deep_diff);
use Refute::Core::Report;

use Test::More;

note "TESTING to_scalar()";

is to_scalar(undef), "(undef)", "to_scalar undef";
is to_scalar(-42.137), -42.137, "to_scalar number";
is to_scalar("foo bared"), "foo bared", "to_scalar a string as is";

is to_scalar(undef, 1), "undef", "to_scalar undef with quotes";
is to_scalar("foo bar", 1), '"foo bar"', "to_scalar string with quotes";
is to_scalar("\t\0\n\"\\", 1), '"\\t\\0\\n\\"\\\\"', "to_scalar escape";

like to_scalar( Refute::Core::Report->new )
    , qr{bless.*Refute::Core::Report}
    , "to_scalar blessed";

like to_scalar( { foo => { bar => 42 }, baz => [[[[]]]] }, 1 ),
    qr(^\{[^\[\]\{\}]*\})s, "depth limit worked";
note to_scalar( { foo => { bar => 42 }, baz => [[[[]]]] }, 1 );

is to_scalar( [] ), "[]", "to_scalar empty array";
is to_scalar( {} ), "{}", "to_scalar empty hash";

like to_scalar( [foo => 42] ), qr(^\[\"foo\", *42\]$), "array with scalars";
like to_scalar( {foo => 42} ), qr(^\{ *foo *=> *42 *\}$), "hash with scalars";

done_testing;
