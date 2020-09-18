#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Refute::Report;

my $main = Refute::Report->new;
my $outer = Refute::Report->new;
my $inner = Refute::Report->new;

$outer->set_parent( $main );
$inner->set_parent( $outer );

is $main->get_depth, 0, "depth default";
is $inner->get_depth, 2, "depth recursive";

done_testing;
