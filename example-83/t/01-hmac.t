#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Digest::SHA qw(sha256_hex hmac_sha256_hex);

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
sub _parse {
    my $out = shift;
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

sub _sign {
    my ($secret, $method, $path, $ts, $nonce, $body) = @_;
    my $canon = join("\n", $method, $path, $ts, $nonce, sha256_hex(defined $body ? $body : ''));
    return hmac_sha256_hex($canon, $secret);
}
sub _signed {
    my ($method, $path, %o) = @_;
    my $key    = $o{key}    // 'keyA';
    my $secret = $o{secret} // 'secret-A';
    my $ts     = $o{ts}     // time;
    my $nonce  = $o{nonce}  // ('n' . int(rand(1_000_000_000)));
    my $body   = $o{body};
    my $sig    = defined $o{sig} ? $o{sig} : _sign($secret, $method, $path, $ts, $nonce, $body);

    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    my %hdrs = (
        'X-Api-Key'   => $key,
        'X-Timestamp' => $ts,
        'X-Nonce'     => $nonce,
        'X-Signature' => $sig,
    );
    delete $hdrs{ $o{omit} } if $o{omit};
    push @cmd, '-H', "$_: $hdrs{$_}" for sort keys %hdrs;
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    return _parse(_raw(@cmd));
}

is(_parse(_raw('curl', '-s', '--max-time', '18', '-i', "$BASE/api/ping"))->{code}, '200', 'ping 200');

# 서명된 GET
{
    my $r = _signed('GET', '/resource');
    is($r->{code}, '200', 'signed GET 200');
    is(_json($r)->{key}, 'keyA', 'key echoed');
}

# 서명된 POST (본문 포함)
{
    my $body = '{"hello":"world"}';
    my $r = _signed('POST', '/resource', body => $body);
    is($r->{code}, '200', 'signed POST 200');
    is(_json($r)->{received}{hello}, 'world', 'body echoed');
}

# 서명 불일치
{
    my $r = _signed('GET', '/resource', sig => ('0' x 64));
    is($r->{code}, '401', 'bad signature 401');
    is(_json($r)->{error}, 'bad_signature', 'bad_signature');
}

# 없는 키
{
    my $r = _signed('GET', '/resource', key => 'ghost', secret => 'x');
    is($r->{code}, '401', 'unknown key 401');
    is(_json($r)->{error}, 'unknown_key', 'unknown_key');
}

# 만료된 타임스탬프 (오래된)
is(_signed('GET', '/resource', ts => time - 1000)->{code}, '401', 'stale ts 401');

# 미래 타임스탬프 (오차 초과)
is(_signed('GET', '/resource', ts => time + 1000)->{code}, '401', 'future ts 401');

# 타임스탬프 비정상
is(_signed('GET', '/resource', ts => 'abc')->{code}, '401', 'non-numeric ts 401');

# 재전송(nonce 재사용) 방지
{
    my $ts = time;
    my $nonce = 'fixed-nonce-xyz';
    my $sig = _sign('secret-A', 'GET', '/resource', $ts, $nonce, undef);
    my $first  = _signed('GET', '/resource', ts => $ts, nonce => $nonce, sig => $sig);
    my $second = _signed('GET', '/resource', ts => $ts, nonce => $nonce, sig => $sig);
    is($first->{code}, '200', 'first use 200');
    is($second->{code}, '409', 'replay 409');
    is(_json($second)->{error}, 'replay', 'replay');
}

# 헤더 누락
{
    my $r = _signed('GET', '/resource', omit => 'X-Signature');
    is($r->{code}, '401', 'missing header 401');
    is(_json($r)->{error}, 'missing_signature', 'missing_signature');
}

# 다른 키로 검증 (keyB)
{
    my $r = _signed('GET', '/resource', key => 'keyB', secret => 'secret-B');
    is($r->{code}, '200', 'keyB works');
    is(_json($r)->{key}, 'keyB', 'keyB echoed');
}

done_testing();
