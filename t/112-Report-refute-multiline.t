#!/usr/bin/env perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Report;

subtest "Return 1 - don't log it" => sub {
    my $report = Refute::Report->new;
    $report->not_ok( 1, "dummy" );

    is $report->get_tap, "not ok 1 - dummy\n", "No info except failed test";
};

subtest "Refute string - log as is" => sub {
    my $report = Refute::Report->new;
    $report->not_ok( "foo bared", "dummy" );

    is $report->get_tap, "not ok 1 - dummy\n# foo bared\n"
        , "Log the reason verbatim";
};

subtest "Interpolate scalar" => sub {
    my $report = Refute::Report->new;
    $report->not_ok( {foo => 42}, "dummy" );

    my @tap = split /\n/, $report->get_tap;
    is $tap[0], "not ok 1 - dummy", "Failing test logged";
    like $tap[1], qr/^# \{\W*foo\W+42\W*\}$/, "Interpolated reason";
    is scalar @tap, 2, "No more lines";
};

subtest "Multiline diag" => sub {
    my $report = Refute::Report->new;
    $report->not_ok( [{foo => 42}, undef, "plain text" ], "dummy" );

    my @tap = split /\n/, $report->get_tap;
    is $tap[0], "not ok 1 - dummy", "Failing test logged";
    like $tap[1], qr/^# \{\W*foo\W+42\W*\}$/, "Interpolated reason";
    like $tap[2], qr/^# \W+undef\W+$/, "undef mentioned";
    is $tap[3], "# plain text", "Plain text inserted as is";
    is scalar @tap, 4, "No more lines";
};

done_testing;
