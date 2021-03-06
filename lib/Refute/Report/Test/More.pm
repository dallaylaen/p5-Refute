package Refute::Report::Test::More;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.17';

=head1 NAME

Refute::Report::Test::More - Test::More compatibility layer for Asser::Refute suite

=head1 SYNOPSIS

In your test script:

    use Test::More;
    use Refute qw(:all); # in that order

    my $def = contract {
        # don't use is/ok/etc here
        my ($c, @args) = @_;
        $c->is (...);
        $c->like (...);
    };

    is foo(), $bar, "Normal test";
    subcontract "Repeated test block 1", $def, $value1;
    like $string, qr/.../, "Another normal test";
    subcontract "Repeated test block 2", $def, $value2;

    done_testing;

=head1 DESCRIPTION

This class is useless in and of itself.
It is auto-loaded as a bridge between L<Test::More> and L<Refute>,
B<if> Test::More has been loaded B<before> Refute.

=head1 METHODS

We override some methods of L<Refute::Report> below so that
test results are fed to the more backend.

=cut

use Carp;

use parent qw(Refute::Report);
use Refute::Builder qw(to_scalar);

=head2 new

Will automatically load L<Test::Builder> instance,
which is assumed to be a singleton as of this writing.

=cut

sub new {
    my ($class, %opt) = @_;

    confess "Test::Builder not initialised, refusing toi proceed"
        unless Test::Builder->can("new");

    my $self = $class->SUPER::new(%opt);
    $self->{builder} = Test::Builder->new; # singletone this far
    $self;
};

=head2 not_ok( $condition, $message )

The allmighty not_ok() boils down to

     ok !$condition, $message
        or diag $condition;

=cut

sub not_ok {
    my ($self, $reason, $mess) = @_;

    # TODO bug - if not_ok() is called directly as $contract->not_ok,
    # it will report the wrong file & line
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    $self->{count} = $self->{builder}->current_test;
    $self->{builder}->ok(!$reason, $mess);

    # see Refute::Report->get_result_detail
    if (ref $reason eq 'ARRAY') {
        $self->{builder}->diag(to_scalar($_)) for @$reason;
    } elsif ($reason and $reason ne 1) {
        $self->{builder}->diag(to_scalar($reason));
    };

    # Do we even need to track it here?
    $self->SUPER::not_ok($reason, $mess);
};

=head2 subcontract

Proxy to L<Test::More>'s subtest.

=cut

sub subcontract {
    my ($self, $mess, $todo, @args) = @_;

    $self->{builder}->subtest( $mess => sub {
        my $rep = (ref $self)->new( builder => $self->{builder} )->do_run(
            $todo, @args
        );
        # TODO also save $rep result in $self
    } );
};

=head2 done_testing

Proxy for C<done_testing> in L<Test::More>.

=cut

sub done_testing {
    my $self = shift;

    $self->{builder}->done_testing;
    $self->SUPER::done_testing;
};

=head2 diag( @message )

=head2 note( @message )

=cut

sub diag {
    my $self = shift;

    $self->SUPER::diag(@_);
    $self->{builder}->diag( join " ", map { to_scalar($_) } @_ );

    return $self;
};

sub note {
    my $self = shift;

    $self->SUPER::note(@_);
    $self->{builder}->note( join " ", map { to_scalar($_) } @_ );

    return $self;
};

=head2 get_count

Current test number.

=cut

sub get_count {
    my $self = shift;
    return $self->{builder}->current_test;
};

=head2 is_passing

Tell if the whole set is passing.

=cut

sub is_passing {
    my $self = shift;
    return $self->{builder}->is_passing;
};

=head2 get_result

Fetch result of n-th test.

0 is for passing tests, a true value is for failing ones.

=cut

sub get_result {
    my ($self, $n) = @_;

    return $self->{fail}{$n} || 0
        if exists $self->{fail}{$n};

    my @t = $self->{builder}->summary;
    $self->_croak( "Test $n has never been performed" )
        unless $n =~ /^[1-9]\d*$/ and $n <= @t;

    # Alas, no reason here
    return !$t[$n];
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<Refute> suite.

Copyright 2017-2018 Konstantin S. Uvarin. C<< <khedin at cpan.org> >>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1;
