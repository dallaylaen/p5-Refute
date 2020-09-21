package Refute::Report::Stdout;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.17';

=head1 NAME

Refute::Report::Stdout - write TAP to a filehandle, like a normal unit test would

=cut

use parent 'Refute::Report';

# TODO lol

=head2 new( file => GLOB )

C<file> defaults to C<\*STDERR>.

=cut

sub new {
    my $class = shift;
    my %opt = @_;

    # TODO validate options

    my $self = $class->SUPER::new();
    $self->{file} = $opt{file} || \*STDOUT;
    $self->{pid}  = $$;
    $self;
};

1;
