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
    my ($method, $path, $body, $key) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, ('-H', "X-API-Key: $key") if defined $key;
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

# 키 없으면 401
is(_req('GET', '/api/data')->{code}, '401', 'missing key 401');

# 기본 한도 5: 5번은 200
for my $i (1 .. 5) {
    my $r = _req('GET', '/api/data', undef, 'k1');
    is($r->{code}, '200', "call $i ok");
    is($r->{headers}{'x-usage-remaining'}, 5 - $i, "remaining after $i");
}

# 6번째는 429 + Retry-After
{
    my $r = _req('GET', '/api/data', undef, 'k1');
    is($r->{code}, '429', 'quota exceeded 429');
    is(_json($r)->{limit}, 5, 'limit in body');
    is(_json($r)->{used}, 5, 'used in body');
    ok($r->{headers}{'retry-after'}, 'Retry-After set');
}

# 사용량 조회 (소모 없음)
{
    my $d = _json(_req('GET', '/usage?key=k1'));
    is($d->{used}, 5, 'used 5');
    is($d->{limit}, 5, 'limit 5');
    is($d->{remaining}, 0, 'remaining 0');
    # 조회는 소모하지 않음
    is(_json(_req('GET', '/usage?key=k1'))->{used}, 5, 'usage does not consume');
}

# 다른 키는 영향 없음
is(_req('GET', '/api/data', undef, 'k2')->{code}, '200', 'other key unaffected');
is(_json(_req('GET', '/usage?key=k2'))->{used}, 1, 'k2 used 1');

# 한도 상향
{
    is(_req('PUT', '/quota', _j({ key => 'k1', limit => 10 }))->{code}, '200', 'raise limit');
    is(_req('GET', '/api/data', undef, 'k1')->{code}, '200', 'ok after raise');
    is(_json(_req('GET', '/usage?key=k1'))->{used}, 6, 'used 6');
}

# 리셋
{
    is(_req('POST', '/quota/reset', _j({ key => 'k1' }))->{code}, '200', 'reset');
    is(_json(_req('GET', '/usage?key=k1'))->{used}, 0, 'used 0 after reset');
    is(_req('GET', '/api/data', undef, 'k1')->{code}, '200', 'ok after reset');
}

# 검증
is(_req('GET', '/usage')->{code}, '400', 'usage without key 400');
is(_req('PUT', '/quota', _j({ key => 'x' }))->{code}, '400', 'limit required 400');
is(_req('PUT', '/quota', _j({ key => 'x', limit => -1 }))->{code}, '400', 'negative limit 400');
is(_req('POST', '/quota/reset', '{}')->{code}, '400', 'reset key required 400');

done_testing();
