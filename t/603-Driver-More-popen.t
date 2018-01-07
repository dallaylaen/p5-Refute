#!perl

use strict;
use warnings;
use Test::More;

# Calculate where Assert::Refute loads from
my $path;
eval {
    my $mod = 'Assert/Refute.pm';
    require $mod;
    my $full = $INC{$mod};
    $full =~ s#/\Q$mod\E$## or die "Cannot determine location from path $full";
    $path = $full;
} || do {
    plan tests => 1;
    ok 0, "Failed to load Assert::Refute: $@";
    exit 1;
};

if ($path =~ /["\$]/) {
    plan skip_all => "Path noth suitable for subshelling: $path";
    exit;
};

# This boilerplate protects from printing to STDERR
# And also lets Assert::Refute know it's under Test::More
my $preamble = <<"PERL";
BEGIN {open STDERR, q{>&STDOUT} or die \$!};
use Test::More;
use warnings FATAL=>qw(all);
use lib q{$path};
use Assert::Refute;

PERL
# Avoid variable interpolation
my $q = $^O eq 'MSWin32' ? q{"} : q{'};

# Pack all boilerplate together and output a string
sub run_cmd {
    my $cmd = shift;

    $cmd =~ /"'/ and die "No quotes in command, use qq{...} instead";

    my $pid = open my $fd, "-|", qq{$^X -e ${q}$preamble$cmd${q}}
        or die "Failed to run perl: $!";

    local $/;
    my $out = <$fd>;
    die "Failed to read from pipe: $!"
        unless defined $out;

    return $out;
};

# Actual tests begin

my $diag = run_cmd( "diag q{IF YOU SEE THIS, TEST FAILED}" );
like $diag, qr/IF YOU SEE/, "(self-test) STDERR is captured";

note "HAPPY PATH";
my $smoke = run_cmd( "refute 0, q{good}; done_testing;" );
is $smoke, "ok 1 - good\n1..1\n", "Happy case";

note "FAIL";
my $smoke_bad = run_cmd( "refute q{reason}, q{bad}; done_testing;" );
like $smoke_bad, qr/^not ok 1/, "test failed";
like $smoke_bad, qr/\n# *reason/, "reason preserved";
like $smoke_bad, qr/\n1..1\n/s, "plan present";

note "SUBTEST";
my $smoke_subtest = run_cmd( "subcontract inner => sub { refute reason => q{fail} for 1..2 }; done_testing;" );
like $smoke_subtest, qr/\nnot ok 1 - inner/, "subtest failed";
like $smoke_subtest, qr/\n +not ok 2/, "Inner test there";
like $smoke_subtest, qr/\n +# reason/, "Fail reason present";

note "SUBTEST CONTENT\n$smoke_subtest/SUBTEST CONTENT";

done_testing;