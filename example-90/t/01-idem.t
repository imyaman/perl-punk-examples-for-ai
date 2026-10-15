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
    my ($method, $path, $body, $ikey) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, ('-H', "Idempotency-Key: $ikey") if defined $ikey;
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

# 키 없이 생성
{
    my $r = _req('POST', '/payments', _j({ amount => 100, currency => 'usd' }));
    is($r->{code}, '201', 'create 201');
    is(_json($r)->{currency}, 'USD', 'currency upper');
    is(_json($r)->{id}, 1, 'id 1');
}

# 키 A로 생성
my $idA;
{
    my $r = _req('POST', '/payments', _j({ amount => 500, currency => 'KRW' }), 'key-A');
    is($r->{code}, '201', 'create with key 201');
    $idA = _json($r)->{id};
    ok(!$r->{headers}{'idempotency-replayed'}, 'first time not replayed');
}

# 같은 키 + 같은 본문 -> 재생(replay), 동일 id
{
    my $r = _req('POST', '/payments', _j({ amount => 500, currency => 'KRW' }), 'key-A');
    is($r->{code}, '201', 'replay 201');
    is(_json($r)->{id}, $idA, 'same id');
    is($r->{headers}{'idempotency-replayed'}, 'true', 'replayed header');
}

# 같은 키 + 다른 본문 -> 409
{
    my $r = _req('POST', '/payments', _j({ amount => 999, currency => 'KRW' }), 'key-A');
    is($r->{code}, '409', 'different payload 409');
}

# 다른 키 -> 새 결제
{
    my $r = _req('POST', '/payments', _j({ amount => 500, currency => 'KRW' }), 'key-B');
    is($r->{code}, '201', 'new key 201');
    isnt(_json($r)->{id}, $idA, 'different id');
}

# 목록에는 실제 결제만 (재생으로 늘지 않음)
{
    my $d = _json(_req('GET', '/payments'));
    is($d->{count}, 3, 'three payments total');
}

# 단건
is(_req('GET', "/payments/$idA")->{code}, '200', 'get payment');
is(_req('GET', '/payments/999')->{code}, '404', 'missing 404');

# 검증: 실패한 요청은 키에 저장되지 않음
{
    is(_req('POST', '/payments', _j({ amount => -1, currency => 'KRW' }), 'key-C')->{code}, '400', 'bad amount 400');
    my $r = _req('POST', '/payments', _j({ amount => 10, currency => 'KRW' }), 'key-C');
    is($r->{code}, '201', 'key-C usable after prior failure');
    ok(!$r->{headers}{'idempotency-replayed'}, 'not treated as replay');
}

is(_req('POST', '/payments', '{}')->{code}, '400', 'amount required 400');
is(_req('POST', '/payments', _j({ amount => 1, currency => 'us' }))->{code}, '400', 'bad currency 400');

done_testing();
