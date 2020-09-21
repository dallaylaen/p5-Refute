package Refute::Report::Fake;

=head1 NAME

Refute::Report::Fake - replace Test::More and Test::Builder with refute.

=cut

use strict;
use warnings;
our $VERSION = '0.17';

use Carp;
use Import::Into;
use parent 'Refute::Report::Stdout';
use Refute::Builder;

our @ISA;
my $loaded = 0;
my $pid = 0;

sub import {
    $loaded++ and return;

    my $class = shift;

    # just in case
    croak __PACKAGE__." must be initialized before Test::More/Test::Builder"
        if Test::More->can("ok") or Test::Builder->can("new");

    require Test::More;
    require Test::Builder;

    push @ISA, qw(Test::Builder);

    no warnings 'redefine'; ## no critic

    foreach (@Refute::Common::EXPORT) {
        no strict 'refs'; ## no critic
        undef *{ "Test::More::$_" };
    };
    Refute::Common->import::into( 'Test::More' );
    *Test::Builder::new = *Test::Builder::new = sub {
        undef $Refute::DRIVER
            if $pid != $$;
        $pid = $$;
        return $Refute::DRIVER ||= __PACKAGE__->new;
    };
};

=head2 plan

Allow empty plan as Test::More seems to do that, otherwise use C<plan>.

=cut

sub plan {
    my $self = shift;
    return unless @_; # Test::More does this
    $self->SUPER::plan(@_);
};

END {
    return unless $pid == $$ and $Refute::DRIVER;

    # $@ will be set if exception was unhandled, and reset if it was caught
    # e.g. in a throws_ok test
    $Refute::DRIVER->done_testing($@ || 0); # tentatively finish

    print $Refute::DRIVER->get_tap;

    exit !$Refute::DRIVER->is_passing;
};

1;
