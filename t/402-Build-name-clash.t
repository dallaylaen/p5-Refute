#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Builder qw(build_refute);
use Refute::Errors;

dies_like {
    build_refute is_taken => sub {1};
} '', "First time ok";

dies_like {
    build_refute is_taken => sub {1};
} qr/build_refute.*is_taken.*already/, "Second time = no go";

dies_like {
    build_refute get_taken => sub {1};
} qr/build_refute.*start.*get_/, "Don't pick ambigous names";

done_testing;
