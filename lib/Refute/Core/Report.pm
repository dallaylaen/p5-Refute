package Refute::Core::Report;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.17';

=head1 NAME

Refute::Core::Report - Contract execution class for Assert::Refute suite

=head1 DESCRIPTION

This class represents one specific application of contract.
It is mutable, but can only changed in one way
(there is no undo of tests and diagnostic messages).
Eventually a C<done_testing> locks it completely, leaving only
L</QUERYING PRIMITIVES> for inspection.

See L<Assert::Refute::Contract> for contract I<definition>.

=head1 SYNOPSIS

    my $c = Refute::Core::Report->new;
    $c->refute ( $cond, $message );
    $c->refute ( $cond2, $message2 );
    # .......
    $c->done_testing; # no more refute after this

    $c->get_count;    # how many tests were run
    $c->is_passing;   # did any of them fail?
    $c->get_tap;      # return printable summary in familiar format

=cut

# Now this module is the CORE of Assert::Refute.
# There are 3 things for which performance matters:
# 1) new()
# 2) refute( 0, ... )
# 3) done_testing()
# The rest can wait.

use Carp;
use Scalar::Util qw( blessed weaken );

use Refute::Builder qw(to_scalar);

# Always add basic testing primitives to the arsenal
require Assert::Refute::T::Basic;

my $ERROR_DONE = "done_testing was called, no more changes may be added";

=head1 METHODS

=head3 new

    Refute::Core::Report->new();

No arguments are currently supported.

=cut

# NOTE keep it simple for performance reasons
sub new {
    bless {
        fail   => {},
        count  => 0,
    }, shift;
};

=head2 RUNNING PRIMITIVES

=head3 plan( tests => $n )

Plan to run exactly n tests.
This is not required, and L</done_testing> (see below)
is needed at the end anyway.

=head3 plan( skip_all => $reason )

Plan to run no tests at all.
As of current, this does not prevent any future checks from being run.

In both cases,
dies if there's already a plan, or tests are being run, or done_testing
was seen.

If plan is not fullfilled by the time of C<done_testing> call,
a message indicating plan violation will be added,
and the report will become unconditionally failing.

=cut

my %allow_plan;
$allow_plan{$_}++ for qw( tests skip_all title );

sub plan {
    my $self = shift;
    $self->_croak("Odd number of arguments in plan()")
        if @_ % 2;
    my %args = @_;

    my @extra = grep { !$allow_plan{$_} } keys %args;
    $self->_croak( "Unknown options to plan(): ".join ",", sort @extra )
        if @extra;
    $self->_croak( "Useless use of plan() without arguments" )
        unless %args;

    $self->_croak( $ERROR_DONE )
        if $self->{done};

    $self->_croak( "plan(): already defined" )
        if defined $self->{plan_tests};
    $self->_croak( "plan(): testing already started" )
        if $self->{count} > 0;

    if ($args{skip_all}) {
        $self->{plan_skip} = $args{skip_all};
        $self->{plan_tests} = 0;
        # TODO should we lock report?
    } elsif (defined $args{tests}) {
        $self->_croak( "plan(): usage: plan tests => n")
            unless $args{tests} =~ /^[0-9]+$/;
        # TODO should we forbid tests => 0 w/o a reason?
        $self->{plan_tests} = int $args{tests};
    };

    if ($args{title}) {
        $self->set_title( $args{title} );
    };

    return $self;
};

=head3 refute( $condition, $message )

An inverted assertion. That is, it B<passes> if C<$condition> is B<false>.

Returns inverse of first argument.
Dies if L</done_testing> was called.

See L<Assert::Refute/refute> for more detailed discussion.

=cut

sub refute {
    my ($self, $cond, $msg) = @_;

    $self->_croak( $ERROR_DONE )
        if $self->{done};

    my $n = ++$self->{count};
    $self->{name}{$n} = $msg if defined $msg;
    delete $self->{log}; # log is a shortcut to $self->{messages}{$n}
                         # see do_log()

    # Pass, return ASAP
    return $n unless $cond;

    # Test failed!
    $self->{fail}{$n} = $cond;
    $self->{fail_count}++;
    return 0;
};

=head3 diag

    diag "Message", \%reference, ...;

Add human-readable diagnostic message to report.
References are auto-explained via L<Data::Dumper>.

=head3 note

    diag "Message", \%reference, ...;

Add human-readable notice message to report.
References are auto-explained via L<Data::Dumper>.

=cut

sub diag {
    my $self = shift;

    $self->do_log( 0, -1, join " ", map { to_scalar($_) } @_ );
};

sub note {
    my $self = shift;

    $self->do_log( 0, 1, join " ", map { to_scalar($_) } @_ );
};

=head3 done_testing

Stop testing.
After this call, no more writes (including done_testing)
can be performed on this contract.
This happens by default at the end of C<contract{ ... }> block.

Dies if called for a second time, I<unless> an argument is given.

A true argument is considered to be the exception
that interrupted the contract execution,
resulting in an unconditionally failed contract.

A false argument just avoids dying and is equivalent to

    $report->done_testing
        unless $report->is_done;

Returns self.

=cut

sub done_testing {
    my ($self, $exception) = @_;

    if ($exception) {
        # Record a totally failing contract.
        delete $self->{done};
        $self->{has_error} = $exception;
    } elsif ($self->{done}) {
        # A special case - done_testing(0) means "tentative stop"
        return $self if defined $exception;
        $self->_croak( $ERROR_DONE );
    };

    # Any post-mortem messages go to a separate bucket
    $self->{log} = $self->{messages}{ -1 } ||= [];

    if ($self->{has_error}) {
        $self->diag( "Looks like contract was interrupted by", $self->{has_error} );
    };

    if (defined $self->{plan_tests}) {
        # Check plan
        if ($self->{count} != $self->{plan_tests}) {
            my $bad_plan = "Looks like you planned $self->{plan_tests}"
                ." tests but ran $self->{count}";
            $self->{has_error} ||= $bad_plan;
            $self->diag( $bad_plan );
        };
    };

    if ($self->{fail_count}) {
        $self->diag(
            "Looks like $self->{fail_count} tests out of $self->{count} have failed");
        my $ctx = $self->context;
        foreach (keys %$ctx) {
            $self->diag("context: $_:", $ctx->{$_});
        };
    };

    $self->{done}++;
    return $self;
};

=head3 context()

Get execution context hash with arbitrary user data.

Upon failure, the hash content is going to be appended to the log at diag level.

=cut

sub context {
    my $self = shift;
    return $self->{context} ||= {};
};

=head3 set_context( \%hash )

Set the context hash.

Only plain (not blessed) hash is allowed as argument.

=cut

sub set_context {
    my ($self, $hash) = @_;

    $self->_croak( "argument must be a HASH reference" )
        unless ref $hash eq 'HASH';

    $self->{context} = $hash;
    return $self;
};

=head3 set_title

Set the a contract title
that briefly explains what we are trying to prove, and why.

See also L</get_title>.

B<[EXPERIMENTAL]>. Name and meaning may change in the future.

=cut

# TODO setter
sub set_title {
    my ($self, $str) = @_;

    $self->_croak( $ERROR_DONE )
        if $self->{done};

    $self->{title} = $str;
    return $self;
};

=head2 TESTING PRIMITIVES

L<Assert::Refute> comes with a set of basic checks
similar to that of L<Test::More>, all being wrappers around
L</refute> discussed above.
They are available as both prototyped functions (if requested) I<and>
methods in contract execution object and its descendants.

The list is as follows:

C<is>, C<isnt>, C<ok>, C<use_ok>, C<require_ok>, C<cmp_ok>,
C<like>, C<unlike>, C<can_ok>, C<isa_ok>, C<new_ok>,
C<contract_is>, C<is_deeply>, C<fail>, C<pass>, C<note>, C<diag>.

See L<Assert::Refute::T::Basic> for more details.

Additionally, I<any> checks defined using L<Refute::Builder>
will be added to L<Refute::Core::Report> as methods
unless explicitly told otherwise.

=head3 subcontract( "Message" => $specification, @arguments ... )

Execute a previously defined group of tests and fail loudly if it fails.

$specification may be one of:

=over

=item * code reference - will be executed in C<eval> block, with a I<new>
L<Refute::Core::Report> passed as argument.

Exceptions are rethrown, leaving a failed contract behind.

    $report->subcontract( "My code" => sub {
        my $new_report = shift;
        # run some checks here
    } );

=item * L<Assert::Refute::Contract> instance - apply() will be called;

As of v.0.15, contract swallows exceptions, leaving behind a failed
contract report only. This MAY change in the future.

=item * L<Refute::Core::Report> instance from a previously executed test.

=back

B<[NOTE]> that the message comes first, unlike in C<refute> or other
test conditions, and is required.

=cut

sub subcontract {
    my ($self, $msg, $sub, @args) = @_;

    $self->_croak( $ERROR_DONE )
        if $self->{done};
    $self->_croak( "Name is required for subcontract" )
        if !$msg or ref $msg;

    my $rethrow;
    my $rep;
    if ( blessed $sub and $sub->isa( "Assert::Refute::Contract" ) ) {
        $rep = $sub->apply(@args);
    } elsif (blessed $sub and $sub->isa( "Refute::Core::Report" ) ) {
        $self->_croak("pre-executed subcontract cannot take args")
            if @args;
        $self->_croak("pre-executed subcontract must be finished")
            unless $sub->is_done;
        $rep = $sub;
    } elsif (UNIVERSAL::isa( $sub, 'CODE' )) {
        $rep = Refute::Core::Report->new->set_parent($self);
        eval {
            # This is ripoff of do_run - maybe just call do_run here
            local $Assert::Refute::DRIVER = $rep;
            $sub->($rep, @args);
            $rep->done_testing(0);
            1;
        } or do {
            $rethrow = $@ || Carp::shortmess("Subcontract execution interrupted");
            $rep->done_testing( $rethrow );
        };
    } else {
        $self->_croak("subcontract must be a coderef, a Contract object, or a finished Report object");
    };

    $self->{subcontract}{ $self->get_count + 1 } = $rep;
    my $ret = $self->refute( !$rep->is_passing, "$msg (subtest)" );
    die $rethrow if $rethrow;
    return $ret;
};

=head2 QUERYING PRIMITIVES

=head3 is_done

Tells whether done_testing was seen.

=cut

sub is_done {
    my $self = shift;
    return $self->{done} || 0;
};


=head3 is_passing

Tell whether the contract is passing or not.

=cut

sub is_passing {
    my $self = shift;

    return !$self->{fail_count} && !$self->{has_error};
};

=head3 get_count

How many tests have been executed.

=cut

sub get_count {
    my $self = shift;
    return $self->{count};
};

=head3 get_fail_count

How many tests failed

=cut

sub get_fail_count {
    my $self = shift;
    return $self->{fail_count} || 0;
};

=head3 get_tests

Returns a list of test ids, preserving order.

=cut

sub get_tests {
    my $self = shift;
    return 1 .. $self->{count};
};

=head3 get_failed_ids

List the numbers of tests that failed.

=cut

sub get_failed_ids {
    my $self = shift;

    return my @list = sort { $a <=> $b } keys %{ $self->{fail} || {} };
};

=head3 get_result( $id )

Returns result of test denoted by $id, dies if such test was never performed.
The result is false for passing tests and whatever the reason for failure was
for failing ones.

=cut

sub get_result {
    my ($self, $n) = @_;

    return $self->{fail}{$n} || 0
        if exists $self->{fail}{$n};

    return 0 if $n =~ /^[1-9]\d*$/ and $n<= $self->{count};

    $self->_croak( "Test $n has never been performed" );
};

=head3 get_result_details ($id)

Returns a hash containing information about a test:

=over

=item * number - the number of test (this is equal to argument);

=item * name - name of the test (if any);

=item * ok - whether the test was successful;

=item * reason - the reason for test failing, if it failed;
Undefined for "ok" tests.

=item * diag - diagnostic messages as one array, without leading C<#>;

=item * log - any log messages that followed the test (see get_log for format)

=item * subcontract - if test was a subcontract, contains the report.

=back

Returns empty hash for nonexistent tests, and dies if test number is not integer.

As a special case, tests number 0 and -1 represent the output before any
tests and postmortem output, respectively.
These only contains the C<log> and C<diag> fields.

See also L<Refute::Test::Tester>.

B<[EXPERIMENTAL]>. Name and meaning may change in the future.

=cut

sub get_result_details {
    my ($self, $n) = @_;

    $self->_croak( "Bad test number $n, must be nonnegatine integer" )
        unless defined $n and $n =~ /^(?:[0-9]+|-1)$/;

    # Process messages, return if premature(0) or post-mortem (n+1)
    my @messages;
    if (my $array = $self->{messages}{$n} ) {
        @messages = @$array;
    };

    my %ret = ( number => $n );

    if ($n >= 1) {
        # a real test - add some information
        my $reason = $self->{fail}{$n};
        my @diag;

        if (ref $reason eq 'ARRAY') {
            push @diag, [ 0, -1, to_scalar($_) ] for @$reason;
        } elsif ( $reason and $reason ne 1 ) {
            push @diag, [ 0, -1, to_scalar($reason) ];
        };

        $ret{ok}          = !$reason;
        $ret{name}        = $self->{name}{$n};
        $ret{reason}      = $reason;
        $ret{log}         = [@diag, @messages];
        $ret{subcontract} = $self->{subcontract}{$n};
    } else {
        # leading or trailing messages
        $ret{log} = \@messages,
    };

    # Strip extra trash from internal log format
    $ret{diag} = [ map { $_->[2] } grep { $_->[1] < 0 } @{ $ret{log} } ];

    return \%ret;
};

=head3 get_error

Return last error that was recorded during contract execution,
or false if there was none.

=cut

sub get_error {
    my $self = shift;
    return $self->{has_error} || '';
};

=head3 get_tap( $level )

Return a would-be Test::More script output for current contract.

The level parameter allows to adjust verbosity level.
The default is 0 which includes passing tests,
but not notes and/or debugging messages.

B<[NOTE]> that C<diag> is higher than C<ok>.

=over

=item * -3 - something totally horrible, like C<Bail out!>

=item * -2 - a failing test

=item * -1 - a diagnostic message, think C<Test::More/diag>

=item * 0 - a passing test

=item * 1+ - a normally ignored verbose message, think L<Test::More/note>

=back

=cut

my %padding; # cache level => leading spaces mapping
my $tab = '    ';

sub get_tap {
    my ($self, $verbosity) = @_;

    $verbosity ||= 0;

    my $mess = $self->get_log( $verbosity );

    my @str;
    foreach (@$mess) {
        my ($indent, $level, $mess) = @$_;
        next if $level > $verbosity;

        my $pad  = '    ' x $indent;
        $pad    .= exists $padding{$level}
            ? $padding{$level}
            : ($padding{$level} = _get_padding( $level ));
        $mess    =~ s/\s*$//s;

        foreach (split /\n/, $mess) {
            push @str, "$pad$_";
        };
    };

    return join "\n", @str, '';
};

sub _get_padding {
    my $level = shift;

    return '#' x $level . '# ' if $level > 0;
    return '# ' if $level == -1;
    return '';
};

=head3 get_sign

Produce a terse pass/fail summary (signature)
as a string of numbers and letters.

The format is C<"t(\d+|N)*[rdE]">.

=over

=item * C<t> is always present at the start;

=item * a number stands for a series of passing tests;

=item * C<N> stands for a I<single> failing test;

=item * C<r> stands for a contract that is still B<r>unning;

=item * C<E> stands for a an B<e>xception during execution;

=item * C<d> stands for a contract that is B<d>one.

=back

The format is still evolving.
Capital letters are used to represent failure,
and it is likely to stay like that.

The numeric notation was inspired by Forsyth-Edwards notation (FEN) in chess.

=cut

sub get_sign {
    my $self = shift;

    my @t = ("t");

    my $streak;
    foreach (1 .. $self->{count}) {
        if ( $self->{fail}{$_} ) {
            push @t, $streak if $streak;
            $streak = 0;
            push @t, "N"; # for "not ok"
        } else {
            $streak++;
        };
    };
    push @t, $streak if $streak;

    my $d = $self->get_error ? 'E' : $self->{done} ? 'd' : 'r';
    return join '', @t, $d;
};

=head3 get_title

Returns the contract title
that briefly explains what we are trying to prove, and why.

See also L</set_title>.

B<[EXPERIMENTAL]>. Name and meaning may change in the future.

=cut

# TODO Dumb getter
sub get_title {
    return $_[0]->{title};
};

=head2 DEVELOPMENT PRIMITIVES

Generally one should not touch these methods unless
when subclassing to build a new test backend.

When extending this module,
please try to stick to C<do_*>, C<get_*>, and C<set_*>
to avoid clash with test names.

This is weird and probably has to be fixed at some point.

=head3 do_run( $code, @list )

Run given CODEREF, passing self as both first argument I<and>
current_contract().
Report object is locked afterwards via L</done_testing> call.

Exceptions are rethrown.
As of current, an exception in CODEREF leaves report in an unfinished state.
This may or may not change in the future.

Returns self.

Example usage is

    Refute::Core::Report->new->run( sub {
        like $this, qr/.../;
        can_ok $that, qw(foo bar frobnicate);
    } );

=cut

sub do_run {
    my ($self, $code, @args) = @_;

    local $Assert::Refute::DRIVER = $self;
    $code->($self, @args);
    $self->done_testing(0);

    return $self;
};

=head3 do_log( $indent, $level, $message )

Append a message to execution log.

See L</get_tap($level)> for level descriptions.

=cut

sub do_log {
    my ($self, $indent, $level, $mess) = @_;

    $self->_croak( $ERROR_DONE )
        if $self->{done};

    $self->{log} ||= $self->{messages}{ $self->{count} } ||= [];
    push @{ $self->{log} }, [$indent, $level, $mess];

    return $self;
};

=head3 get_log

Return log messages "as is" as array reference
containing triads of (indent, level, message).

B<[CAUTION]> This currently returns reference to internal structure,
so be careful not to spoil it.
This MAY change in the future.

=cut

sub get_log {
    my ($self, $verbosity) = @_;
    $verbosity = 9**9**9 unless defined $verbosity;

    my @mess;

    # output plan if there was plan
    if (defined $self->{plan_tests}) {
        push @mess, _plan_to_tap( $self->{plan_tests}, $self->{plan_skip} )
            unless $verbosity < 0;
    };

    foreach my $n ( 0 .. $self->{count}, -1 ) {
        # Report test details.
        # Only append the logs for
        #   premature (0) and postmortem (-1) messages
        if ($n > 0) {
            my $reason = $self->{fail}{$n};
            my ($level, $prefix)  = $reason ? (-2, "not ok") : (0, "ok");
            my $name   = $self->{name}{$n} ? "$n - $self->{name}{$n}" : $n;
            push @mess, [ 0, $level, "$prefix $name" ];

            if ($self->{subcontract}{$n}) {
                push @mess, map {
                    [ $_->[0]+1, $_->[1], $_->[2] ];
                } @{ $self->{subcontract}{$n}->get_log( $verbosity ) };
            };

            if (ref $reason eq 'ARRAY') {
                push @mess, map {
                    [ 0, -1, to_scalar( $_ ) ]
                } @$reason;
            } elsif ($reason and $reason ne 1) {
                push @mess, [ 0, -1, to_scalar( $reason ) ];
            };
        };

        # and all following diags
        if (my $rest = $self->{messages}{$n} ) {
            push @mess, grep { $_->[1] <= $verbosity } @$rest;
        };
    };

    if (!defined $self->{plan_tests} and $self->{done}) {
        push @mess, _plan_to_tap( $self->get_count )
            unless $verbosity < 0;
    };

    return \@mess;
};

sub _plan_to_tap {
    my ($n, $skip) = @_;

    my $line = "1..".$n;
    $line .= " # SKIP $skip"
        if defined $skip;
    return [ 0, 0, $line ];
};

=head2 set_parent

    $report->set_parent($bigger_report);
    $report->set_parent(undef);

Indicate that a contract is part of a larger one.
The parent object should be an L<Refute::Core::Report> instance.
The parent object reference will be weakened to avoid memory leak.

Provide C<undef> as argument to erase parent information.

Returns self, so that calls to set_parent can be chained.

This is used internally by L</subcontract>.

B<NOTE> As of 0.16, no C<isa>/C<DOES> check on the argument is enforced.
It must be blessed, however.
This MAY change in the future.

=cut

sub set_parent {
    my ($self, $parent) = @_;

    if (blessed $parent) {
        $self->{parent} = $parent;
        # avoid a circular loop because $self is likely to be stored
        # in parent as subcontract
        weaken $self->{parent};
    } elsif (!defined $parent) {
        delete $self->{parent};
    } else {
        $self->_croak('parent must be a Report object, not a '.(ref $parent || 'scalar'))
    };
    return $self;
};

=head2 get_parent

Return parent contract, i.e. the contract we are subcontract of, if any.

Always check get_parent to be defined
as it will vanish if parent object goes out of scope.
This is done so to avoid memory leak in subcontract call.

=cut

# Dumb getter
sub get_parent {
    return $_[0]->{parent};
};

=head2 get_depth

Returns 0 is there is no parent, or parent's depth + 1.
This of this as "this contract's indentation level".

B<EXPERIMENTAL>. Name and meaning MAY change in the future.

=cut

sub get_depth {
    my $self = shift;

    if (!exists $self->{depth}) {
        my $parent = $self->get_parent;
        $self->{depth} = $parent ? $parent->get_depth + 1 : 0;
    };

    return $self->{depth};
};

sub _croak {
    my ($self, $mess) = @_;

    $mess ||= "Something terrible happened";
    $mess =~ s/\n+$//s;

    my $fun = (caller 1)[3];
    $fun =~ s/(.*)::/${1}->/;

    croak "$fun(): $mess";
};

=head1 LICENSE AND COPYRIGHT

This module is part of L<Assert::Refute> suite.

Copyright 2017-2018 Konstantin S. Uvarin. C<< <khedin at cpan.org> >>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

=cut

1; # End of Refute::Core::Report
