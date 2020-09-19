package Assert::Refute;

use 5.006;
use strict;
use warnings;
our $VERSION = '0.17';

=head1 NAME

Assert::Refute - Unified testing and assertion tool

=head1 DESCRIPTION

This module allows injecting L<Test::More>-like code snippets
into production code, without turning the whole application
into a giant testing script.

This can be though of as a lightweight design-by-contract form.

=head1 SYNOPSIS

The following code will die unless the conditions listed there are fulfilled:

    use Assert::Refute ":all", { on_fail => 'croak' };

    # Lots of code here
    try_refute {
        cmp_ok $price + $fee, "==", $total, "Money added up correctly";
        like $description, qr/\w{3}/, "A readable description is present";
        isa_ok $my_obj, "My::Class";
    };

A code snippet like this can guard important invariants,
ensure data correctness, or serve as a safety net while reworking
a monolithic application into separate testable modules.

Note that the inside of the block can be copied into a unit-test as is,
giving one a fine-grained I<speed E<lt>----E<gt> accuracy> control.

The same can be done without polluting the main package namespace:

    use Assert::Refute { on_fail => 'croak' };

    try_refute {
        my $report = shift;
        $report->cmp_ok( $price + $fee, "==", $total, "Money added up correctly" );
        $report->like( $description, qr/\w{3}/, "A readable description is present" );
        $report->isa_ok( $my_obj, "My::Class" );
    };

Relying on a global (in fact, per-package) callback is not required:

    use Assert::Refute {}, ":all";

    my $report = try_refute {
        # ... assertions here
    };
    if (!$report->is_passing) {
        $my_logger->error( "Something is not right: ".$report->get_tap );
        # do whatever error handling is needed
    };

See L<Refute::Core::Report> for more information about the underlying
object-oriented interface.

=head1 ASSERTIONS, CONTRACTS, AND SUBCONTRACTS

=over

=item * We use the term I<assertion> here to refer to a binary statement
that can be proven wrong using a well-defined, finite calculation.

We say that assertion I<fail>s if such proof is provided,
and I<pass>es otherwise.

"X equals Y" and "a string contains such and such words"
are assertions by this definition.
"This code terminates" isn't because it requires solving the halting problem.
"All swans are white" isn't either unless there's code that produces
a black swan.

=item * We use the term I<contract> here to refer to a code block
containing zero or more assertions.
A contract is said to I<fail> if any of its assertions fails,
and is assumed to I<pass> otherwise.

This is not to be confused with full-fledged design-by-contract
which is much more specific about what contracts are.

=item * Note that a contract itself is an assertion by this definition.
We use the term I<subcontract> to refer to an assertion that another
contract passes given certain arguments.

These building blocks allow to create and verify
arbitrarily complex specifications.
See L</PERFORMANCE> below for limitations, though.

=back

=head1 EXPORT

Any number of hash references may be added to the C<use> statement,
resulting in an implicit C<Assert::Refute-E<gt>configure> call.
A literal C<{}> will also trigger C<configure>.

Everything else will be passed on to L<Exporter>.

    use Assert::Refute;

as well as

    use Assert::Refute qw(:core);

would only export C<try_refute>, C<contract>, C<refute>,
C<contract_is>, C<subcontract>, and C<current_contract> functions.

Also for convenience some basic assertions mirroring the L<Test::More> suite
are exportable via C<:all> and C<:basic> export tag.

    use Assert::Refute qw(:all);

would also export the following assertions:

C<is>, C<isnt>, C<ok>, C<use_ok>, C<require_ok>, C<cmp_ok>,
C<like>, C<unlike>, C<can_ok>, C<isa_ok>, C<new_ok>,
C<is_deeply>, C<fail>, C<pass>, C<note>, C<diag>.

See L<Assert::Refute::T::Basic> for more.

This distribution also bundles some extra assertions:

=over

=item * L<Assert::Refute::T::Array> - inspect list structure;

=item * L<Assert::Refute::T::Errors> - verify exceptions and warnings;

=item * L<Assert::Refute::T::Hash> - inspect hash keys and values;

=item * L<Assert::Refute::T::Numeric> - make sure numbers fit certain intervals;

=back

These need to be C<use>d explicitly.

=cut

use Carp;
use Exporter;

use Refute::Core::Report;
use Refute::Builder qw(current_contract);
use Assert::Refute::T::Basic;

my @basic = (
    @Assert::Refute::T::Basic::EXPORT, 'plan'
);
my @core  = qw(
    contract refute_these try_refute
    refute subcontract contract_is current_contract
);
my @extra = qw( assert_refute refute_and_report refute_invariant );

our @ISA = qw(Exporter);
our @EXPORT = @core;
our @EXPORT_OK = (@basic, @extra);

our %EXPORT_TAGS = (
    basic => [@basic],
    core  => [@core, @extra],
    all   => [@EXPORT, @EXPORT_OK],
);

our $DRIVER; # Used by other modules, declaration JFYI
our %CALLER_CONF;

our $NDEBUG;
$NDEBUG = $ENV{PERL_NDEBUG} unless defined $NDEBUG;
$NDEBUG = $ENV{NDEBUG} unless defined $NDEBUG;

sub import {
    my $class = shift;

    # NOTE ugly hack - allow for 'use Assert::Refute {}'
    # this should not be needed with new assert_refute / refute_and_report API
    my %conf = ( on_fail => 'skip' );
    my (@exp, $need_conf);
    foreach (@_) {
        if (ref $_ eq 'HASH') {
            %conf = (%conf, %$_);
            $need_conf++;
        } elsif (!ref $_ and $_ eq '{}') {
            # TODO 0.15 remove together with auto-carp
            $need_conf++; # allow for -MAssert::Refute={}
        } elsif (!ref $_) {
            push @exp, $_;
        } else {
            croak "Unexpected argument in Assert::Refute->import: ".ref $_;
        };
    };

    $class->configure( \%conf, scalar caller ) if $need_conf;
    $class->export_to_level(1, undef, @exp);
};

my %known_callback = (
    skip => '',
    carp => sub {
        my $report = shift;
        warn $report->get_tap . _report_mess( $report );
    },
    croak => sub {
        my $report = shift;
        die $report->get_tap . _report_mess( $report );
    },
);

# TODO maybe public method in Report?
sub _report_mess {
    my $report = shift;

    my $state = $report->is_passing ? "passed" : "failed";
    my $title = $report->get_title;
    my $str   = $title ? "Contract '$title' $state" : "Contract $state";
    return Carp::shortmess($str);
};

my %default_conf = (
    on_fail => 'carp',
    on_pass => 'skip',
);

=head2 try_refute { ... }

Check whether given contract BLOCK containing zero or more assertions passes.

Contract will fail if any of the assertions fails,
a C<plan> is declared and not fulfilled,
or an exception is thrown.
Otherwise it is assumed to pass.

The BLOCK must accept one argument, the contract execution report,
likely a L<Refute::Core::Report> instance.

More arguments MAY be added in the future.
Return value is ignored.

A read-only report instance is returned by C<try_refute> instead.

If C<on_pass>/C<on_fail> callbacks were specified during C<use> or
using C<configure>, they will also be executed if appropriate.

If C<NDEBUG> or C<PERL_NDEBUG> environment variable is set at compile time,
this block is replaced with a stub
which returns an unconditionally passing report.

This is basically what one expects from a module in C<Assert::*> namespace.

=cut

sub try_refute(&;@) { ## no critic # need prototype
    my ( $block, @arg ) = @_;

    # Should a missing config even happen? Ok, play defensively...
    my $conf = $CALLER_CONF{+caller};
    if( !$conf ) {
        $conf = __PACKAGE__->configure( {}, scalar caller );
    };
    return $conf->{skip_all} if exists $conf->{skip_all};

    my $report = $conf->{driver}->new;
    eval {
        $report->do_run($block);
        1;
    } || do {
        $report->done_testing(
            $@ || Carp::shortmess( 'Contract execution interrupted' ) );
    };

    # perform whatever action is needed
    my $callback = $conf->{ $report->is_passing ? "on_pass" : "on_fail" };
    $callback->($report) if $callback;

    return $report;
};

=head2 assert_refute { ... }

Check whether given contract BLOCK containing zero or more assertions passes.

Contract will fail if any of the assertions fail
or a C<plan> is declared and not fulfilled.
Otherwise it is assumed to pass.

Unlike with try_refute, exceptions are just let through.

The BLOCK must accept one argument, the contract execution report,
likely a L<Refute::Core::Report> instance.

More arguments MAY be added in the future.
Return value is ignored.

A read-only report instance is returned by C<try_refute> instead.

If C<on_pass>/C<on_fail> callbacks were specified during C<use> or
using C<configure>, they will also be executed if appropriate.

If C<NDEBUG> or C<PERL_NDEBUG> environment variable is set at compile time,
this block is replaced with a stub
which returns an unconditionally passing report.

This is basically what one expects from a module in C<Assert::*> namespace.

B<[EXPERIMENTAL]>. Name and behavior MAY change in the future.
Should this function prove useful, it will become the successor
or C<try_refute>.

=cut

sub assert_refute(&;@) { ## no critic # need prototype
    unshift @_, '';

    goto &_real_assert;
};

=head2 refute_invariant "name" => sub { ... }

A named runtime assertion.

Exactly as above, except that a title is added to the report object
which will be appended to the emitted warning/error (if any).

Title can be queried via C<get_title> method in report object.

B<[EXPERIMENTAL]>. Name and meaning may change in the future.

=cut

sub refute_invariant(@) { ## no critic # need prototype
    my ( $name, $block, @arg ) = @_;

    croak q{Usage: refute_invariant "name" => sub { ... }"}
        unless $name and ref $block eq 'CODE';

    goto &_real_assert;
};

sub _real_assert {
    my ( $name, $block ) = @_;

    # Should a missing config even happen? Ok, play defensively...
    my $conf = $CALLER_CONF{+caller};
    if( !$conf ) {
        # TODO add configure_global & use default configuration
        $conf = __PACKAGE__->configure( { on_fail => 'carp' }, scalar caller );
    };
    return $conf->{skip_all} if exists $conf->{skip_all};

    my $report = $conf->{driver}->new->set_title($name)->do_run($block);

    # perform whatever action is needed
    my $callback = $conf->{ $report->is_passing ? "on_pass" : "on_fail" };
    $callback->($report) if $callback;

    return $report;
};

=head2 refute_and_report { ... }

Run a block of code with a fresh L<Refute::Core::Report> object as argument.
Lock the report afterwards and return it.

For instance,

    my $report = refute_and_report {
        my $c = shift;
        $c->is( $price * $amount, $total, "Numbers add up" );
        $c->like( $header, qr/<h1>/, "Header as expected" );
        $c->can_ok( $duck, "quack" );
    };

Or alternatively one may resort to L<Test::More>-like DSL:

    use Assert::Refute qw(:all);
    my $report = refute_and_report {
        is      $price * $amount, $total, "Numbers add up";
        like    $header, qr/<h1>/, "Header as expected";
        can_ok  $duck, "quack";
    };

This method does not adhere C<NDEBUG>, apply callbacks, or handle expections.
It just executes the checks.
Not exported by default.

B<[EXPERIMENTAL]>. Name and behavior MAY change in the future.
Should this function prove useful, it will become the successor
or C<try_refute>.

=cut

sub refute_and_report (&;@) { ## no critic # need prototype
    my ( $block, @arg ) = @_;

    return Refute::Core::Report->new->do_run($block);
};

=head2 contract { ... }

Save a contract BLOCK for future use:

    my $contract = contract {
        my ($foo, $bar) = @_;
        # conditions here
    };

    # much later
    my $report = $contract->apply( $real_foo, $real_bar );
    # Returns an Refute::Core::Report with conditions applied

This is similar to how C<prepare> / C<execute> works in L<DBI>.

B<[DEPRECATED]> This function will disappear in v.0.20.

Prior to advent of C<try_refute>, this call used to be the main entry point
to this module.
This is no more the case, and a simple subroutine containing assertions
would fit in most places where C<contract> is appropriate.

Use L<Assert::Refute::Contract/contract> instead.

=cut

sub contract (&@) { ## no critic
    carp "contract{ ... } is DEPRECATED, use Assert::Refute::Contract::contract instead";

    require Assert::Refute::Contract;
    goto &Assert::Refute::Contract::contract;
};

=head2 plan tests => $n

Plan to run exactly C<n> assertions within a contract block.
Plan is optional, contract blocks can run fine without a plan.

A contract will fail unconditionally if plan is present and is not fulfilled.

C<plan> may only be called before executing any assertions.
C<plan> dies if called outside a contract block.

Not exported by default to avoid namespace pollution.

=head2 plan skip_all => $reason

B<[EXPERIMENTAL]>.
Like above, but plan is assumed to be zero and a reason for that is specified.

Note that the contract block is not interrupted,
it's up to the user to call return.
This MAY change in the future.

=cut

sub plan(@) { ## no critic
    current_contract->plan( @_ );
};

=head2 refute( $reason, $message )

Verify (or, rather, try hard to disprove)
an assertion in scope of the current contract.

The test passes if the C<$reason> is I<false>, i.e. an empty string, C<0>,
or C<undef>.
Otherwise the C<$reason> is assumed to be a description of what went wrong.

You can think of it as C<ok> and C<diag> from L<Test::More> combined:

    ok !$reason, $message
        or diag $reason;

As a special case, a literal C<1> is considered to be a boolean value
and the assertions just fails, without further explanation.

As another special case, an C<\@arrayref> reason
will be unfolded into multiple C<diag> lines, for instance

    refute [ $answer, "isn't", 42 ], "life, universe, and everything";

will output 3 diag lines.

Returns true for a passing assertion and false for a failing one.
Dies if no contract is being executed at the time.

=cut

sub refute ($$) { ## no critic
    current_contract()->refute(@_);
};

=head2 subcontract( "Message" => $contract, @arguments )

"The specified contract passes, given the arguments" assertion.
This is similar to C<subtest> in L<Test::More>.

B<[NOTE]> that the message comes first, unlike in C<refute>
or other assertion types, and is I<required>.

A I<contract> may be an L<Assert::Refute::Contract> object,
a plain subroutine with some assertions inside, or
an L<Refute::Core::Report> instance from a previous contract run.

A subroutine MUST accept an empty L<Refute::Core::Report> object.

For instance, one could apply a previously defined validation to a
structure member:

    my $valid_email = contract {
        my $email = shift;
        # ... define your checks here
    };

    my $valid_user = contract {
        my $user = shift;
        is ref $user, 'HASH'
            or die "Bail out - not a hash";
        like $user->{id}, qr/^\d+$/, "id is a number";
        subcontract "Check e-mail" => $valid_email, $user->{email};
    };

    # much later
    $valid_user->apply( $form_input );

Or pass a definition as I<argument> to be applied to specific structure parts
(think I<higher-order functions>, like C<map> or C<grep>).

    my $array_of_foo = contract {
        my ($is_foo, $ref) = @_;

        foreach (@$ref) {
            subcontract "Element check", $is_foo, $_;
        };
    };

    $array_of_foo->apply( $valid_user, \@user_list );

=cut

sub subcontract($$@) { ## no critic
    current_contract()->subcontract( @_ );
};

=head2 contract_is

    contract_is $report, $signature, "Message";

Assert that a contract is fulfilled exactly to the specified extent.
See L<Refute::Core::Report/get_sign> for signature format.

This may be useful for verifying assertions and contracts themselves.

This is actually a clone of L<Assert::Refute::T::Basic/contract_is>.

=cut

=head2 current_contract

Returns the L<Refute::Core::Report> object being worked on.

If L<Test::Builder> has been detected and no contract block
is executed explicitly, returns a L<Assert::Refute::Driver::More> instance.
This allows to define assertions and run them uniformly under
both L<Assert::Refute> and L<Test::More> control.

Dies if no contract could be detected.

It is actually a clone of L<Refute::Builder/current_contract>.

=head1 STATIC METHODS

Use these methods to configure Assert::Refute globally.

=head2 configure

    use Assert::Refute \%options;
    Assert::Refute->configure( \%options );
    Assert::Refute->configure( \%options, "My::Package");

Set per-caller configuration values for given package.
C<configure> is called implicitly by C<use Assert::Refute { ... }>
if hash parameter(s) are present.

%options may include:

=over

=item * on_pass - callback to execute if tests pass (default: C<skip>)

=item * on_fail - callback to execute if tests fail (default: C<carp>,
but not just C<Carp::carp> - see below).

=item * driver - use that class instead of L<Refute::Core::Report>
as contract report.

=item * skip_all - reason for skipping ALL C<try_refute> blocks
in the affected package.
This defaults to C<PERL_NDEBUG> or C<NDEBUG> environment variable.

B<[EXPERIMENTAL]>. Name and meaning MAY change in the future.

=back

The callbacks MUST be either
a C<CODEREF> accepting L<Refute::Core::Report> object,
or one of predefined strings:

=over

=item * skip - do nothing;

=item * carp - warn the stringified report;

=item * croak - die with stringified report as error message;

=back

Returns the resulting config (with default values added,etc).

As of current, this method only affects C<try_refute>.

=cut

my %conf_known;
$conf_known{$_}++ for qw( on_pass on_fail driver skip_all );

sub configure {
    my ($class, $given_conf, $caller) = @_;

    croak "Usage: $class->configure( \\%hash, \$target )"
        unless ref $given_conf eq 'HASH';

    my @extra = grep { !$conf_known{$_} } keys %$given_conf;
    croak "$class->configure: unknown parameters (@extra)"
        if @extra;

    # configure whoever called us by default
    $caller ||= scalar caller;

    my $conf = { %default_conf, %$given_conf };
    $conf->{on_fail} = _coerce_cb($conf->{on_fail});
    $conf->{on_pass} = _coerce_cb($conf->{on_pass});

    # Load driver
    if( $conf->{driver} ) {
        my $mod = "$conf->{driver}.pm";
        $mod =~ s#::#/#g;
        require $mod;
        croak "$conf->{driver} is not Refute::Core::Report, cannot use as driver"
            unless $conf->{driver}->isa('Refute::Core::Report');
    } else {
        $conf->{driver} = 'Refute::Core::Report'; # this works for sure
    };

    if ($NDEBUG and !$conf->{skip_all}) {
        $conf->{skip_all} = "Assert::Refute turned off via NDEBUG=$NDEBUG";
    };

    if ($conf->{skip_all}) {
        my $default_report = $conf->{driver}->new;
        $default_report->plan( skip_all => $conf->{skip_all} );
        $default_report->done_testing;
        $conf->{skip_all} = $default_report;
    } else {
        delete $conf->{skip_all};
    };

    $CALLER_CONF{$caller} = $conf;
};

=head2 configure_global( \%global_defaults )

Set a global configuration to be used as default.

This can be used e.g. to set an assertion failure callback throughout
a big project.

=cut

sub configure_global {
    my ($class, $conf) = @_;

    croak "Usage: $class->configure_global( \\%hash )"
        unless ref $conf eq 'HASH';

    my @extra = grep { !$conf_known{$_} } keys %$conf;
    croak "$class->configure_global: unknown parameters (@extra)"
        if @extra;

    $default_conf{$_} = $conf->{$_}
        for keys %$conf;

    return $class; # oh really?
};

=head2 get_config

Returns configuration from above, initializing with defaults if needed.

=cut

sub get_config {
    my ($class, $caller) = @_;

    $caller ||= scalar caller;
    return $CALLER_CONF{$caller} ||= $class->configure({}, $caller);
};

sub _coerce_cb {
    my $sub = shift;

    $sub = defined $known_callback{$sub} ? $known_callback{$sub} : $sub;
    return unless $sub;
    croak "Bad callback $sub"
        unless ref $sub and UNIVERSAL::isa( $sub, 'CODE' );
    return $sub;
};

=head2 refute_these

B<[DEPRECATED]> This used to be the old name of C<try_refute>.
It just dies now and will be removed completely in the future.

=cut

# TODO v.0.20 remove completely
# Keep it prototyped just in case some poor guy/gal forgot to change it
#     or else they'll get a very confusing error message
sub refute_these (&;@) { ## no critic # need prototype
    croak "refute_these { ... } is no more supported, use try_refute{ ... } instead";
}

=head1 EXTENDING THE SUITE

Although building wrappers around C<refute> call is easy enough,
specialized tool exists for doing that.

Use L<Refute::Builder> to define new I<checks> as
both prototyped exportable functions and their counterpart methods
in L<Refute::Core::Report>.
These functions will perform absolutely the same
under control of C<try_refute>, C<contract>, and L<Test::More>:

    package My::Prime;

    use Refute::Builder;
    use parent qw(Exporter);

    build_refute is_prime => sub {
        my $n = shift;
        return "Not a natural number: $n" unless $n =~ /^\d+$/;
        return "$n is not prime" if $n <= 1;
        for (my $i = 2; $i*$i <= $n; $i++) {
            return "$i divides $n" unless $n % $i;
        };
        return '';
    }, args => 1, export => 1;

Much later:

    use My::Prime;

    is_prime 101, "101 is prime";
    is_prime 42, "Life is simple"; # not true

Note that the implementation C<sub {...}> only cares about its arguments,
and doesn't do anything except returning a value.
Suddenly it's a L<pure function|https://en.wikipedia.org/wiki/Pure_function>!

Yet the exact reason for $n not being a prime will be reflected in test output.

One can also subclass L<Refute::Core::Report>
to create new I<drivers>, for instance,
to register failed/passed tests in a unit-testing framework of choice
or generate warnings/exceptions when conditions are not met.

That's how L<Test::More> integration is done -
see L<Assert::Refute::Driver::More>.

=head1 PERFORMANCE

Set C<NDEBUG> or C<PERL_NDEBUG> (takes precedence)
environment variable to true to replace I<all> C<try_refute> blocks with a stub.
L<Carp::Assert> was used as reference.

If that's not enough, use L<Keyword::DEVELOPMENT>
or just define a DEBUG constant and
append an C<if DEBUG;> statement to C<try_refute{ ... }> blocks.

That said, refute is reasonably fast.
Special care is taken to minimize the CPU usage by I<passing> contracts.

The C<example/00-benchmark.pl> file in this distribution is capable of
verifying around 4000 contracts of 100 statements each in just under a second
on my 4500 C<BOGOMIPS> laptop.
Your mileage may vary!

=head1 WHY REFUTE

Communicating a passing test normally requires 1 bit of information:
everything went as planned.
For failing test, however, as much information as possible is desired.

Thus C<refute($condition, $message)> stands for an inverted assertion.
If $condition is B<false>, it is regarded as a B<success>.
If it is B<true>, however, it is considered to be the B<reason>
for a failing test.

This is similar to how Unix programs set their exit code,
or to Perl's own C<$@> variable,
or to the I<falsifiability> concept in science.

A C<subcontract> is a result of multiple checks,
combined into a single refutation.
It will succeed silently, yet spell out details if it doesn't pass.

These primitives can serve as building blocks for arbitrarily complex
assertions, tests, and validations.

=head1 DEPRECATION WARNING

The following modules used to be part of this package, but are separate
CPAN distributions now:

=over

=item * L<Assert::Refute::T::Array>

=item * L<Assert::Refute::T::Hash>

=item * L<Assert::Refute::T::Numeric>

=item * L<Assert::Refute::T::Scalar>

=back

=head1 SEE ALSO

L<Test::More>, L<Carp::Assert>, L<Keyword::DEVELOPMENT>

=head1 BUGS

This module is still under heavy development.
See C<TODO> file in this distribution for an approximate roadmap.

New features are marked as B<[EXPERIMENTAL]>.
Features that are to be removed will
stay B<[DEPRECATED]> (with a corresponding warning) for at least 5 releases,
unless such deprecation is extremely cumbersome.

Test coverage is maintained at >90%, but who knows what lurks in the other 10%.

See L<https://github.com/dallaylaen/assert-refute-perl/issues>
to browse old bugs or report new ones.

=head1 SUPPORT

You can find documentation for this module with the C<perldoc> command.

    perldoc Assert::Refute

You can also look for information at:

=over

=item * First and foremost, use
L<Github|https://github.com/dallaylaen/assert-refute-perl/>!

=item * C<RT>: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Assert-Refute>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Assert-Refute>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Assert-Refute>

=item * Search CPAN

L<https://metacpan.org/pod/Assert::Refute>

=back

=head1 ACKNOWLEDGEMENTS

=over

=item * Thanks to L<Alexander Kuklev|https://github.com/akuklev>
for C<try_refute> function name as well as a lot of feedback.

=item * This L<rant|https://www.perlmonks.org/?node_id=1122667>
by C<Daniel Dragan> inspired me to actually start working
on the first incarnation of this project.

=item * Thanks to C<Jacobo Chamorro> for pass() and fail() calls.

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2017-2018 Konstantin S. Uvarin. C<< <khedin at cpan.org> >>

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

1; # End of Assert::Refute
