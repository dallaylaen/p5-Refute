#!perl

use strict;
use warnings;
BEGIN { undef @ENV{ qw{NDEBUG PERL_NDEBUG} } };
use Test::More;

use Refute::Errors qw(dies_like);

dies_like {
    package T;
    use Refute qw(refute_invariant);
    refute_invariant '' => sub {};
} qr(Usage: refute_invariant), "no empty name";

dies_like {
    package T;
    use Refute qw(refute_invariant);
    refute_invariant 'good name' => {};
} qr(Usage: refute_invariant), "no empty coderef";

done_testing;

