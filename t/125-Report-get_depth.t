#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;

use Refute::Core::Report;

my $main = Refute::Core::Report->new;
my $outer = Refute::Core::Report->new;
my $inner = Refute::Core::Report->new;

$outer->set_parent( $main );
$inner->set_parent( $outer );

is $main->get_depth, 0, "depth default";
is $inner->get_depth, 2, "depth recursive";

done_testing;
