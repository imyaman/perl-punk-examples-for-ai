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
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _enqueue { my ($type, $payload) = @_;
    my $j = JSON::PP->new->encode({ type => $type, (defined $payload ? (payload => $payload) : ()) });
    return _json(_req('POST', '/jobs', $j));
}
sub _tick { _json(_req('POST', '/worker/tick')) }
sub _job  { _json(_req('GET', "/jobs/$_[0]")) }

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# 큐 적재 + 처리
my $j1;
{
    my $d = _enqueue('sum', { numbers => [1, 2, 3] });
    $j1 = $d->{id};
    is($d->{status}, 'queued', 'enqueued');
    like($d->{poll}, qr{^/jobs/}, 'poll url');

    my $g = _job($j1);
    is($g->{status}, 'queued', 'still queued');
    is($g->{attempts}, 0, 'zero attempts');
}
{
    my $t = _tick();
    is($t->{processed}, $j1, 'tick processed j1');
    is($t->{status}, 'done', 'done after tick');
    my $g = _job($j1);
    is($g->{status}, 'done', 'job done');
    is($g->{result}, 6, 'sum result');
    is($g->{attempts}, 1, 'one attempt');
}

# 실패 -> 자동 재시도 -> 실패
my $jfail;
{
    $jfail = _enqueue('fail', {})->{id};
    my $t1 = _tick();
    is($t1->{status}, 'queued', 'requeued for retry');
    is($t1->{attempts}, 1, 'attempt 1');
    my $t2 = _tick();
    is($t2->{status}, 'failed', 'failed after max attempts');
    is($t2->{attempts}, 2, 'attempt 2');

    my $g = _job($jfail);
    is($g->{status}, 'failed', 'job failed');
    like($g->{error}, qr/fail/i, 'error recorded');
}

# 실패 작업 재시도: 같은 실패를 반복
{
    my $r = _req('POST', "/jobs/$jfail/retry");
    is($r->{code}, '200', 'retry 200');
    is(_json($r)->{status}, 'queued', 'requeued');
    is(_job($jfail)->{attempts}, 0, 'attempts reset');
    is(_tick()->{status}, 'queued', 'retry attempt 1');
    is(_tick()->{status}, 'failed', 'failed again');
}

# FIFO 순서
{
    my $a = _enqueue('sum', { numbers => [10] })->{id};
    my $b = _enqueue('sum', { numbers => [20] })->{id};
    is(_tick()->{processed}, $a, 'FIFO first');
    is(_tick()->{processed}, $b, 'FIFO second');
    is(_job($a)->{result}, 10, 'A result');
    is(_job($b)->{result}, 20, 'B result');
}

# 알 수 없는 작업 -> 실패
{
    my $u = _enqueue('nope', {})->{id};
    _tick();
    my $t = _tick();
    is($t->{status}, 'failed', 'unknown type fails');
    like(_job($t->{processed})->{error}, qr/unknown task/, 'unknown error');
}

# 잘못된 페이로드
{
    $j = _enqueue('sum', { numbers => ['x'] })->{id};
    _tick();
    my $t = _tick();
    is($t->{status}, 'failed', 'invalid payload fails');
    like(_job($j)->{error}, qr/numeric/, 'numeric error');
}

# retry 규칙
is(_req('POST', '/jobs/j-9999/retry')->{code}, '404', 'retry unknown 404');
{
    my $q = _enqueue('sum', { numbers => [9] })->{id};
    is(_req('POST', "/jobs/$q/retry")->{code}, '409', 'retry non-failed 409');
    _tick();   # drain
}

# 빈 큐
{
    my $t = _tick();
    ok(!defined $t->{processed}, 'nothing to process');
}

# 목록/집계
{
    my $d = _json(_req('GET', '/jobs'));
    is($d->{total}, 7, 'seven jobs');
    cmp_ok($d->{by_status}{done}, '>=', 4, 'several done');
    cmp_ok($d->{by_status}{failed}, '>=', 3, 'several failed');
    is($d->{queued}, 0, 'queue drained');
}

# 입력 검증
is(_req('POST', '/jobs', '{}')->{code}, '400', 'missing type 400');

done_testing();
