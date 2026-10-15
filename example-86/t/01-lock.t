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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my ($code, %h);
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _j { JSON::PP->new->encode($_[0]) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 획득
my $token;
{
    my $r = _req('POST', '/locks/job42', _j({ owner => 'alice', ttl => 60 }));
    is($r->{code}, '201', 'acquire 201');
    my $d = _json($r);
    $token = $d->{token};
    ok($token, 'token returned');
    is($d->{ttl}, 60, 'ttl');
}

# 동시 획득 실패
{
    my $r = _req('POST', '/locks/job42', _j({ owner => 'bob' }));
    is($r->{code}, '409', 'conflict 409');
    is(_json($r)->{holder}{owner}, 'alice', 'holder is alice');
    ok($r->{headers}{'retry-after'}, 'Retry-After set');
}

# 조회
{
    my $d = _json(_req('GET', '/locks/job42'));
    is($d->{owner}, 'alice', 'owner alice');
}

# 갱신
is(_req('PUT', '/locks/job42/renew', _j({ token => 'wrong' }))->{code}, '403', 'renew wrong token 403');
{
    my $r = _req('PUT', '/locks/job42/renew', _j({ token => $token, ttl => 120 }));
    is($r->{code}, '200', 'renew 200');
    is($r->{code} eq '200' ? (_json($r)->{ttl} > 60 ? 1 : 0) : 0, 1, 'ttl extended');
}

# 해제
is(_req('DELETE', '/locks/job42', _j({ token => 'wrong' }))->{code}, '403', 'release wrong token 403');
is(_req('DELETE', '/locks/job42', _j({ token => $token }))->{code}, '204', 'release 204');
is(_req('GET', '/locks/job42')->{code}, '404', 'gone 404');

# 해제 후 재획득
is(_req('POST', '/locks/job42', _j({ owner => 'bob' }))->{code}, '201', 'reacquire 201');

# TTL 만료로 자동 해제
{
    my $r = _req('POST', '/locks/shortlived', _j({ owner => 'carol', ttl => 0.3 }));
    is($r->{code}, '201', 'short acquire');
    is(_req('POST', '/locks/shortlived', _j({ owner => 'dave' }))->{code}, '409', 'held before expiry');
    select(undef, undef, undef, 0.5);
    is(_req('GET', '/locks/shortlived')->{code}, '404', 'expired auto-free');
    is(_req('POST', '/locks/shortlived', _j({ owner => 'dave' }))->{code}, '201', 'acquire after expiry');
}

# 검증
is(_req('POST', '/locks/x', _j({ ttl => 5 }))->{code}, '400', 'owner required 400');
is(_req('POST', '/locks/x', _j({ owner => 'a', ttl => 99999 }))->{code}, '400', 'ttl too big 400');
is(_req('POST', '/locks/x', _j({ owner => 'a', ttl => 0 }))->{code}, '400', 'ttl zero 400');
is(_req('GET', '/locks')->{code}, '200', 'list locks');
is(_req('DELETE', '/locks/nope', _j({ token => 't' }))->{code}, '404', 'release missing 404');

done_testing();
