#!perl
use 5.006;
use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

plan tests => 1;

BEGIN {
    require_ok( 'Refute' ) || print "Bail out!\n";
}

diag( "Testing Refute $Refute::VERSION, Perl $], $^X" );
