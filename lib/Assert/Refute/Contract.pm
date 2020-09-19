package Assert::Refute::Contract;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.17';

=head1 NAME

Assert::Refute::Contract - Contract definition class for Assert::Refute suite

=head1 DESCRIPTION

This class represents a contract and is thus immutable.

See L<Refute::Core::Report> for its I<application> to a specific case.

=head1 SYNOPSIS

    use Assert::Refute::Contract;

    my $contract = Assert::Refute::Contract->new(
        code => sub {
            my ($c, $life) = @_;
            $c->is( $life, 42 );
        },
        need_object => 1,
    );

    # much later
    my $result = $contract->apply( 137 );
    $result->get_count;  # 1
    $result->is_passing; # 0
    $result->get_tap;    # Test::More-like summary

=head1 DESCRIPTION

This is a contract B<specification> class.
See L<Refute::Core::Report> for execution log.
See L<Assert::Refute/contract> for convenient interface.

=cut

use Carp;
use parent qw(Exporter);

use Refute::Core::Report;

our @CARP_NOT = qw(Assert::Refute Refute::Builder);
our @EXPORT_OK = qw(contract);

=head1 EXPORT

C<contract> prototyped function is optionally exported.

=head2 contract { ... }

Save a contract BLOCK for future use:

    use Assert::Refute qw(:all);

    my $spec = contract {
        my ($foo, $bar) = @_;
        is $foo, 42, "Life";
        like $bar, qr/b.*a.*r/, "Regex";
    };

    # later
    my $report = $spec->apply( 42, "bard" );
    $report->get_count;  # 2
    $report->is_passing; # true
    $report->get_tap;    # printable summary *as if* it was Test::More

The same may be written as

    my $spec = contract {
        my ($report, @args) = @_;
        $report->is( ... );
        $report->like( ... );
    } need_object => 1;

The C<need_object> form may be preferable if one doesn't want to pollute the
main namespace with test functions (C<is>, C<ok>, C<like> etc)
and instead intends to use object-oriented interface.

Note that contract does B<not> validate anything by itself,
it just creates a read-only L<Assert::Refute::Contract>
object sitting there and waiting for an C<apply> call.

The C<apply> call returns a L<Refute::Core::Report> object containing
results of specific execution.

This is similar to how C<prepare> / C<execute> works in L<DBI>.

This function is equivalent to C<new> (see below)
but may be more convenient in some cases.

=cut

sub contract (&@) { ## no critic
    croak "Odd number of elements in contract { ... } options"
        unless @_ % 2;
    my ($code, %opt) = @_;

    $opt{code} = $code;
    return __PACKAGE__->new( %opt );
};

=head1 OBJECT-ORIENTED INTERFACE

=head2 new

    Assert::Refute::Contract->new( %options );

%options may include:

=over

=item * C<code> (required) - contract to be executed

=item * C<need_object> - if given, a contract execution object
will be prepended to C<code>'s argument list,
as if it was a method.

This allows to run a contract without exporting anything to the calling
package.

The name is not final, better suggestions wanted.

=item * C<args> = n or C<args> = [min, max] - set limitation on
the number of accepted parameters.
Negative maximum value means unlimited.

=back

=cut

my @new_required  = qw( code );
my @new_essential = (@new_required, qw( need_object args ));
my @new_optional  = qw( driver );

my %new_arg;
$new_arg{$_}++ for @new_essential, @new_optional;

my $def_driver = "Refute::Core::Report";

sub new {
    my ($class, %opt) = @_;

    my @missing = grep { !$opt{$_} } @new_required;
    croak( "Missing required arguments: @missing" )
        if @missing;
    croak( "'code' argument must be a subroutine" )
        unless UNIVERSAL::isa($opt{code}, 'CODE');
    my @extra = grep { !$new_arg{$_} } keys %opt;
    croak( "Unknown options: @extra" )
        if @extra;

    $opt{need_object}   = $opt{need_object} ? 1 : 0;

    # argument count:
    # * n means exactly n
    # * (n, m) means from n to m
    # * (n, -1) means from n to inf
    my $args = $opt{args};
    $args = [0, -1] unless defined $args; # == 0 is ok
    $args = [ $args, $args ] unless ref $args eq 'ARRAY';
    $args->[1] = 9**9**9 if $args->[1] < 0;
    croak "Meaningless argument limits [$args->[0], $args->[1]]"
        unless $args->[0] <= $args->[1];
    $opt{args} = $args;

    # TODO validate driver
    $opt{driver}    ||= $def_driver;

    bless \%opt, $class;
};

=head2 adjust( %overrides )

Return a copy of this object with some overridden fields.

The name is not perfect, better ideas wanted.

%overrides may include:

=over

=item * driver - the class to perform tests.

=back

=cut

sub adjust {
    my ($self, %opt) = @_;

    my @dont = grep { $opt{$_} } @new_essential;
    croak( "Attempt to override essential parameters @dont" )
        if @dont;

    if (defined $opt{backend}) {
        # TODO 0.20 kill it
        carp( (ref $self)."->adjust: 'backend' is deprecated, use 'driver' instead");
        $opt{driver} = delete $opt{backend};
    };

    return (ref $self)->new( %$self, %opt );
};

=head2 apply( @parameters )

Spawn a new execution log object and run contract against it.

Returns a locked L<Refute::Core::Report> instance.

=cut

sub apply {
    my ($self, @args) = @_;

    my $c = $self->{driver};
    $c = $c->new unless ref $c;
    # TODO plan tests, argument check etc

    croak "contract->apply: expected from $self->{args}[0] to $self->{args}[1] parameters"
        unless $self->{args}[0] <= @args and @args <= $self->{args}[1];

    unshift @args, $c if $self->{need_object};
    local $Assert::Refute::DRIVER = $c;
    eval {
        $self->{code}->( @args );
        $c->done_testing
            unless $c->is_done;
        1;
    } || do {
        $c->done_testing($@ || "Unexpected end of tests");
    };

    # At this point, done_testing *has* been called unless of course
    #    it is broken and dies, in which case tests will fail.
    return $c;
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<Assert::Refute> suite.

Copyright 2017-2018 Konstantin S. Uvarin. C<< <khedin at cpan.org> >>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1; # End of Assert::Refute::Contract
