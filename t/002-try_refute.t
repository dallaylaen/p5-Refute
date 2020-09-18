#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More tests => 2;

use Refute {};

my @warn;
$SIG{__WARN__} = sub { push @warn, $_[0]; warn $_[0] };

my $sign = eval {
    try_refute {
        my $contract = shift;
        $contract->not_ok( 0, "pass" );
        $contract->not_ok( 1, "fail" );
    }->get_sign
};
my $err = $@;

unless (is $sign, "t1Nd", "signature as expected") {
    diag "Exception was: $err" if $err;
    print "Bail out! Basic try_refute{ ... } fails\n";
};

unless (is scalar @warn, 0, "no warnings") {
    print "Bail out! Basic try_refute{ ... } fails\n";
};
