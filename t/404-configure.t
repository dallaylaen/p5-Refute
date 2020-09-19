#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Assert::Refute::T::Errors;
use Assert::Refute;

dies_like {
    package T;
    Assert::Refute->configure( driver => 'Carp' );
} qr/Usage.*hash/, "Hash required";

dies_like {
    package T;
    Assert::Refute->configure({ driver => 'Carp' });
} qr/Carp.*Refute::Core::Report.*driver/, "Carp is not recognized as driver";

done_testing;
