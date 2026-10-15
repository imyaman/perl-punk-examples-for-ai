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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "Authorization: Bearer $h{bearer}" if $h{bearer};
    if (defined $h{body}) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $h{body};
    }
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

# 로그인
my $token;
{
    my $r = _req('POST', '/auth/login', body => '{"user":"alice"}');
    is($r->{code}, '201', 'login 201');
    $token = _json($r)->{token};
    my @parts = split /\./, ($token // '');
    is(scalar @parts, 3, 'jwt has 3 parts');
}

# /me 정상
{
    my $r = _req('GET', '/me', bearer => $token);
    is($r->{code}, '200', 'me 200');
    is(_json($r)->{sub}, 'alice', 'sub');
}

# 토큰 없음 -> 401
is(_req('GET', '/me')->{code}, '401', 'no token 401');

# 잘못된 토큰 -> 401
is(_req('GET', '/me', bearer => 'abc.def.ghi')->{code}, '401', 'bad token 401');

# 서명 위조 -> 401
{
    my ($h, $p, $s) = split /\./, $token;
    is(_req('GET', '/me', bearer => "$h.$p.AAAA")->{code}, '401', 'tampered sig 401');
}

# 페이로드 변조 -> 401
{
    my ($h, $p, $s) = split /\./, $token;
    is(_req('GET', '/me', bearer => "$h.${p}x.$s")->{code}, '401', 'tampered payload 401');
}

# 만료 (ttl=1 후 2초)
{
    my $t = _json(_req('POST', '/auth/login', body => '{"user":"bob","ttl":1}'))->{token};
    is(_req('GET', '/me', bearer => $t)->{code}, '200', 'fresh token 200');
    sleep 2;
    is(_req('GET', '/me', bearer => $t)->{code}, '401', 'expired 401');
}

# user 없음 -> 400
is(_req('POST', '/auth/login', body => '{}')->{code}, '400', 'no user 400');

done_testing();
