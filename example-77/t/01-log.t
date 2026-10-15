#!/usr/bin/perl
use Test::More;
use JSON::PP;

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
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200');

# 몇 번 호출해 로그 생성
my $rid = _get('/api/ping')->{headers}{'x-request-id'};
ok($rid, 'request id header');
is(_get('/api/healthz')->{code}, '200', 'healthz 200');
is(_get('/api/readyz')->{code}, '200', 'readyz 200');

# 로그 조회
{
    my $r = _get('/logs/tail?n=10');
    is($r->{code}, '200', 'tail 200');
    my $d = _json($r);
    cmp_ok($d->{count}, '>=', 3, 'at least 3 entries');

    my @pings = grep { $_->{path} eq '/api/ping' } @{ $d->{entries} };
    ok(scalar @pings, 'ping logged');
    is($pings[-1]{status}, 200, 'status logged');
    is($pings[-1]{method}, 'GET', 'method logged');
    ok(defined $pings[-1]{ms} && $pings[-1]{ms} >= 0, 'timing logged');
    ok(length($pings[-1]{rid} // ''), 'rid logged');
    ok(defined $pings[-1]{ts}, 'ts logged');
}

# n 제한
{
    my $d = _json(_get('/logs/tail?n=1'));
    cmp_ok($d->{count}, '<=', 1, 'limit n');
}

done_testing();
