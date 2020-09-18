#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;
use Refute::Errors;

use Refute qw();

my $sub = sub { warn "Foobared" };

{
    package T;
    Refute->configure({on_pass=>$sub});
};

is( Refute->get_config( "T" )->{on_pass}, $sub
    , "get_config another package" );

ok( !Refute->get_config()->{on_pass}, "get_config caller - gets empty" );

dies_like {
    package T;
    Refute->configure( { foobared => 137 } );
} qr/Refute.*[Uu]nknown.*foobared/, "Unknown param = no go";

done_testing;
