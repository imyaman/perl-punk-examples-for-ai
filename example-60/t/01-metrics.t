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
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
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

# 두 번 호출하여 카운터 증가
_get('/api/ping');
_get('/api/ping');

my $m = _get('/metrics');
is($m->{code}, '200', 'metrics 200');
like($m->{headers}{'content-type'} // '', qr{text/plain}, 'plain text');
like($m->{body}, qr/# TYPE daeha_requests_total counter/, 'counter type');
like($m->{body}, qr{daeha_requests_total\{method="GET",path="/api/ping"\} \d+}, 'ping counter line');
like($m->{body}, qr/daeha_uptime_seconds \d+/, 'uptime gauge');

# ping 카운터가 2 이상
{
    my ($val) = $m->{body} =~ /daeha_requests_total\{method="GET",path="\/api\/ping"\} (\d+)/;
    cmp_ok($val, '>=', 2, 'ping counted at least twice');
}

# /metrics 자체는 카운트되지 않음
unlike($m->{body}, qr{path="/metrics"}, 'metrics not self-counted');

done_testing();
