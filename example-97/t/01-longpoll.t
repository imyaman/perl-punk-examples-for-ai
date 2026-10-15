#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Time::HiRes ();

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
    my $t0 = Time::HiRes::time();
    my $out = _raw(@cmd);
    my $elapsed = Time::HiRes::time() - $t0;
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // ''), elapsed => $elapsed };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _j { JSON::PP->new->encode($_[0]) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 이벤트 생성
{
    my $r = _req('POST', '/events', _j({ type => 'a' }));
    is($r->{code}, '201', 'event 201');
    is(_json($r)->{id}, 1, 'id 1');
}

# 이미 있는 이벤트는 즉시 반환
{
    my $r = _req('GET', '/wait?since=0&timeout_ms=2000');
    is($r->{code}, '200', 'immediate 200');
    is(_json($r)->{event}{id}, 1, 'event id 1');
    is(_json($r)->{waited}, 0, 'waited 0');
    cmp_ok($r->{elapsed}, '<', 0.5, 'returned fast');
}

# 새 이벤트 없으면 timeout 후 204
{
    my $r = _req('GET', '/wait?since=1&timeout_ms=300');
    is($r->{code}, '204', 'timeout 204');
    cmp_ok($r->{elapsed}, '>=', 0.25, 'waited for timeout');
    cmp_ok($r->{elapsed}, '<', 1.5, 'not too long');
}

# 새 이벤트가 생기면 그걸 반환
{
    _req('POST', '/events', _j({ type => 'b' }));
    my $r = _req('GET', '/wait?since=1&timeout_ms=2000');
    is($r->{code}, '200', 'new event 200');
    is(_json($r)->{event}{id}, 2, 'event id 2');
    cmp_ok($r->{elapsed}, '<', 0.5, 'fast when present');
}

# since 로 모두 소진하면 대기
{
    my $r = _req('GET', '/wait?since=2&timeout_ms=200');
    is($r->{code}, '204', 'nothing new 204');
}

# 기본 timeout (명시 안 하면 1000ms) - since 뒤에 없으니 204
{
    my $r = _req('GET', '/wait?since=99');
    is($r->{code}, '204', 'default timeout 204');
}

# 검증
is(_req('GET', '/wait?since=abc')->{code}, '400', 'bad since 400');
is(_req('GET', '/wait?since=0&timeout_ms=0')->{code}, '400', 'timeout 0 400');
is(_req('GET', '/wait?since=0&timeout_ms=99999')->{code}, '400', 'timeout huge 400');
is(_req('POST', '/events', '{}')->{code}, '400', 'type required 400');

done_testing();
