#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Refute::Errors;

use Refute::Report;


dies_like {
    my $rep = Refute::Report->new;
    $rep->subcontract( sub { shift->ok(1) } );
} qr/Refute.*[Nn]ame/, "no name = no game";
note $@;

dies_like {
    my $rep = Refute::Report->new;
    $rep->subcontract( "Ok, a name" => "This fails" );
} qr/Refute.*must be.*code.*[Rreport]/, "Second must be ref";
note $@;

dies_like {
    my $rep = Refute::Report->new;
    $rep->subcontract( "Ok, a name" => Refute::Report->new );
} qr/Refute.*must be.*finished/, "Unfinished report = no go";

dies_like {
    my $rep = Refute::Report->new;
    $rep->subcontract( "Ok, a name" => Refute::Report->new->done_testing, "Extra args" );
} qr/Refute.*cannot take arg/, "Cannot add arguments to report";

done_testing;
