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
sub _req {
    my ($method, $path) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 정상 상태
{
    my $r = _req('GET', '/api/readyz');
    is($r->{code}, '200', 'ready 200');
    ok(_json($r)->{ready}, 'ready true');
    is(_json($r)->{status}, 'ready', 'status ready');
}

# in-flight 계측 (요청 처리 중 1 이상)
{
    ok(_json(_req('GET', '/work'))->{in_flight} >= 1, 'in_flight counted during request');
    is(_json(_req('GET', '/admin/state'))->{in_flight}, 1, 'no leak: only current request in flight');
}

# 드레인 시작
{
    my $r = _req('POST', '/admin/drain');
    is($r->{code}, '200', 'drain 200');
    ok(_json($r)->{draining}, 'draining true');
}

# 레디니스는 503, 라이브니스는 200
{
    my $r = _req('GET', '/api/readyz');
    is($r->{code}, '503', 'readyz 503 while draining');
    ok(!_json($r)->{ready}, 'ready false');
    is(_json($r)->{reason}, 'shutting down', 'reason');
    is(_req('GET', '/api/healthz')->{code}, '200', 'healthz stays 200');
    is(_req('GET', '/api/ping')->{code}, '200', 'ping stays 200');
}

# 드레인 중에도 기존 연결 처리(work)는 동작
is(_req('GET', '/work')->{code}, '200', 'work still allowed');

# 멱등: 다시 drain 해도 200
is(_req('POST', '/admin/drain')->{code}, '200', 'drain idempotent');

# resume
{
    is(_req('POST', '/admin/resume')->{code}, '200', 'resume 200');
    is(_req('GET', '/api/readyz')->{code}, '200', 'ready again');
    is(_req('GET', '/admin/state')->{code}, '200', 'state 200');
}

done_testing();
