#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Assert::Refute::Contract;

{
    package Foo;
    use parent qw(Refute::Core::Report);
};

my $spec = Assert::Refute::Contract->new(
    code => sub {
        $_[0]->is( 42, 137 );
    },
    need_object => 1,
);

my $spec2 = $spec->adjust( driver => 'Foo' );

my $rep = $spec2->apply();

isa_ok( $rep, 'Foo', "New contract" );
isa_ok( $rep, 'Refute::Core::Report', "Nevertheless, new contract" );
is( $rep->get_sign, "tNd", "1 test failed" );

done_testing;

