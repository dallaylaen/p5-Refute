#!/usr/bin/env perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;
use Refute::Errors;

my $report;
dies_like {
    package T;
    use Refute {};
    $report = refute_these {
        not_ok 1, "If you see this message the tests have failed!";
    };
} qr/refute_these.*no more.*try_refute/, "Deprecated, alternative suggested";

done_testing;
