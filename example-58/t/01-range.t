#!/usr/bin/perl
use Test::More;

my $BASE = 'http://127.0.0.1:3004';

sub _raw {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(15);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    return $@ ? '' : $out;
}
sub _get {
    my ($range) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE/file");
    push @cmd, '-H', "Range: $range" if defined $range;
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body // '') };
}

is(_get()->{code}, '200', 'no range 200');
{
    my $r = _get();
    is($r->{headers}{'accept-ranges'}, 'bytes', 'advertises ranges');
    is(length($r->{body}), 200, 'full body 200 bytes');
}

# 0-9
{
    my $r = _get('bytes=0-9');
    is($r->{code}, '206', '0-9 -> 206');
    is($r->{headers}{'content-range'}, 'bytes 0-9/200', 'content-range');
    is(length($r->{body}), 10, '10 bytes');
    is($r->{body}, 'abcdefghij', 'correct slice');
}

# open 10-
{
    my $r = _get('bytes=10-');
    is($r->{code}, '206', 'open -> 206');
    is($r->{headers}{'content-range'}, 'bytes 10-199/200', 'open range header');
    is(length($r->{body}), 190, '190 bytes');
}

# suffix -5
{
    my $r = _get('bytes=-5');
    is($r->{code}, '206', 'suffix -> 206');
    is($r->{headers}{'content-range'}, 'bytes 195-199/200', 'suffix header');
    is(length($r->{body}), 5, '5 bytes');
}

# 불가 범위
{
    my $r = _get('bytes=500-600');
    is($r->{code}, '416', 'out of range 416');
    is($r->{headers}{'content-range'}, 'bytes */200', 'unsatisfied range');
}

done_testing();
