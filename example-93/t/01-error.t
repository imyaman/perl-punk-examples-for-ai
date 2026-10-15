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
    my ($method, $path, $hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, ('-H', $hdr) if defined $hdr;
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

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 정상 요청에도 correlation id 가 붙는다
{
    my $r = _req('GET', '/ok');
    is($r->{code}, '200', 'ok 200');
    ok($r->{headers}{'x-correlation-id'}, 'id on success too');
}

# 예외 -> 500 problem+json
{
    my $r = _req('GET', '/boom');
    is($r->{code}, '500', 'boom 500');
    like($r->{headers}{'content-type'}, qr{application/problem\+json}, 'problem+json');
    my $d = _json($r);
    is($d->{status}, 500, 'status in body');
    ok($d->{correlation_id}, 'correlation id in body');
    is($d->{correlation_id}, $r->{headers}{'x-correlation-id'}, 'id matches header');
    like($d->{detail}, qr/kaboom/, 'detail carries message');
}

# 다른 예외(0으로 나누기)
is(_req('GET', '/divzero')->{code}, '500', 'divzero 500');

# 깊은 호출 스택에서 죽어도 잡힌다
{
    my $r = _req('GET', '/chain');
    is($r->{code}, '500', 'chain 500');
    like(_json($r)->{detail}, qr/inner failure/, 'inner message surfaced');
}

# 상관관계 id 는 요청마다 달라진다
{
    my $a = _req('GET', '/boom')->{headers}{'x-correlation-id'};
    my $b = _req('GET', '/boom')->{headers}{'x-correlation-id'};
    isnt($a, $b, 'distinct ids per request');
}

# 들어온 id 를 존중(에코)
{
    my $r = _req('GET', '/ok', 'X-Correlation-Id: trace-123');
    is($r->{headers}{'x-correlation-id'}, 'trace-123', 'incoming id echoed');
}

# 미정의 경로는 여전히 404 (프레임워크 기본)
is(_req('GET', '/nope')->{code}, '404', 'unknown path 404');

done_testing();
