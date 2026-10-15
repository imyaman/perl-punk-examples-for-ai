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

# 초기: closed, 정상 호출 성공
is(_json(_req('GET', '/circuit'))->{state}, 'closed', 'initial closed');
is(_req('GET', '/api/fetch')->{code}, '200', 'fetch ok');

# 하위 실패 모드
is(_req('POST', '/downstream/mode', _j({ mode => 'fail' }))->{code}, '200', 'set fail');

# 임계(3)까지 502, 세 번째에 회로 OPEN
{
    is(_req('GET', '/api/fetch')->{code}, '502', 'fail 1 -> 502');
    is(_json(_req('GET', '/circuit'))->{state}, 'closed', 'still closed after 1');
    is(_req('GET', '/api/fetch')->{code}, '502', 'fail 2 -> 502');
    my $r = _req('GET', '/api/fetch');
    is($r->{code}, '502', 'fail 3 -> 502');
    is(_json($r)->{state}, 'open', 'opened at threshold');
}

# OPEN: 즉시 503, 하위 호출 안 함
{
    my $r = _req('GET', '/api/fetch');
    is($r->{code}, '503', 'open -> 503');
    is($r->{headers}{'retry-after'} =~ /^\d/ ? 1 : 0, 1, 'Retry-After present');
    is(_json(_req('GET', '/circuit'))->{state}, 'open', 'state open');
}

# open_secs 경과 -> half_open 시험 -> 하위 여전히 실패면 다시 open
select(undef, undef, undef, 1.2);
{
    my $r = _req('GET', '/api/fetch');
    is($r->{code}, '502', 'half-open trial fails 502');
    is(_json($r)->{state}, 'open', 'reopened after failed trial');
}

# 하위 복구 -> 시험 성공 -> closed
is(_req('POST', '/downstream/mode', _j({ mode => 'ok' }))->{code}, '200', 'set ok');
select(undef, undef, undef, 1.2);
{
    my $r = _req('GET', '/api/fetch');
    is($r->{code}, '200', 'recovered 200');
    is(_json($r)->{state}, 'closed', 'closed after success');
    is(_json(_req('GET', '/circuit'))->{failures}, 0, 'failures reset');
}

# 검증
is(_req('POST', '/downstream/mode', _j({ mode => 'bogus' }))->{code}, '400', 'bad mode 400');

done_testing();
