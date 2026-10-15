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

# 창/한도 설정 (빠른 테스트용)
is(_req('PUT', '/ratelimit', _j({ window => 2, limit => 3 }))->{code}, '200', 'configure');
{
    my $d = _json(_req('GET', '/ratelimit'));
    is($d->{window}, 2, 'window 2');
    is($d->{limit}, 3, 'limit 3');
}

# 3회 허용
{
    my @rem;
    for my $i (1 .. 3) {
        my $r = _req('GET', '/api/hit', undef, 'k1');
        is($r->{code}, '200', "hit $i 200");
        push @rem, $r->{headers}{'x-ratelimit-remaining'};
    }
    is_deeply(\@rem, [2, 1, 0], 'remaining decreasing');
}

# 4회째 429
{
    my $r = _req('GET', '/api/hit', undef, 'k1');
    is($r->{code}, '429', '4th 429');
    ok($r->{headers}{'retry-after'}, 'Retry-After set');
    is($r->{headers}{'x-ratelimit-remaining'}, 0, 'remaining 0');
}

# 다른 키는 독립
{
    my $r = _req('GET', '/api/hit', undef, 'k2');
    is($r->{code}, '200', 'other key ok');
    is($r->{headers}{'x-ratelimit-remaining'}, 2, 'k2 remaining 2');
}

# 창이 밀리면 다시 허용 (슬라이딩)
select(undef, undef, undef, 2.2);
{
    is(_req('GET', '/api/hit', undef, 'k1')->{code}, '200', 'allowed after window slides');
}

# 검증
is(_req('PUT', '/ratelimit', _j({ limit => 0 }))->{code}, '400', 'limit 0 400');
is(_req('PUT', '/ratelimit', _j({ window => -1 }))->{code}, '400', 'negative window 400');

done_testing();
