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

# v1: 구 응답 형식 + 폐기 헤더
{
    my $r = _req('GET', '/v1/users');
    is($r->{code}, '200', 'v1 200');
    is_deeply(_json($r)->{users}, ['alice', 'bob'], 'v1 array of names');
    is($r->{headers}{deprecation}, 'true', 'Deprecation header');
    ok($r->{headers}{sunset}, 'Sunset header');
    like($r->{headers}{link} // '', qr{rel="successor-version"}, 'successor Link');
}

# v2: 객체 + 메타
{
    my $d = _json(_req('GET', '/v2/users'));
    is(scalar @{ $d->{data} }, 2, 'v2 data');
    is($d->{data}[0]{name}, 'alice', 'v2 object shape');
    is($d->{meta}{version}, 'v2', 'v2 meta');
}

# v1 에는 폐기 헤더, v2 에는 없음
ok(_req('GET', '/v1/users')->{headers}{deprecation}, 'v1 deprecated');
ok(!_req('GET', '/v2/users')->{headers}{deprecation}, 'v2 not deprecated');

# 버전 발견
{
    my $d = _json(_req('GET', '/version'));
    is($d->{current}, 'v2', 'current v2');
    is_deeply($d->{supported}, ['v1','v2'], 'supported');
    is_deeply($d->{deprecated}, ['v1'], 'deprecated');
}

# 지원하지 않는 버전
is(_req('GET', '/v3/users')->{code}, '404', 'v3 404');

done_testing();
