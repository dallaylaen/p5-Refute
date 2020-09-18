#!perl

use strict;
use warnings;
BEGIN{ delete @ENV{qw(NDEBUG PERL_NDEBUG)} };
use Test::More;

use Refute::Errors;
use Refute;

dies_like {
    package T;
    Refute->configure( driver => 'Carp' );
} qr/Usage.*hash/, "Hash required";

dies_like {
    package T;
    Refute->configure({ driver => 'Carp' });
} qr/Carp.*Refute::Report.*driver/, "Carp is not recognized as driver";

done_testing;
