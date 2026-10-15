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

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# 수신기 상태 확인
{
    my $d = _json(_req('GET', '/hook/sink'));
    is($d->{mode}, 'ok', 'sink mode ok');
    is($d->{count}, 0, 'sink empty');
}

# 성공 경로
my $j1;
{
    my $r = _req('POST', '/events', '{"payload":{"kind":"order.created","order_id":42}}');
    is($r->{code}, '202', 'accepted 202');
    my $d = _json($r);
    is($d->{state}, 'delivered', 'delivered first try');
    is($d->{attempts}, 1, 'one attempt');
    $j1 = $d->{id};
    like($d->{poll}, qr{^/jobs/}, 'poll url');
}

{
    my $d = _json(_req('GET', "/jobs/$j1"));
    is($d->{state}, 'delivered', 'job delivered');
    is($d->{attempts}, 1, 'job attempts');
    is($d->{attempts_log}[0]{ok}, 1, 'attempt ok');
    is($d->{attempts_log}[0]{status}, 200, 'attempt status 200');
    is($d->{payload}{kind}, 'order.created', 'payload kept');
    ok(!defined $d->{next_retry_at}, 'no retry scheduled');
}

# 수신기 도착 확인
{
    my $d = _json(_req('GET', '/hook/sink'));
    is($d->{count}, 1, 'sink received 1');
    is($d->{received}[0]{event_id}, $j1, 'event_id matches');
    is($d->{received}[0]{payload}{order_id}, 42, 'payload delivered');
    is($d->{received}[0]{attempt}, 1, 'attempt number');
}

# 실패 경로: 디드레터
my $j2;
{
    is(_req('POST', '/hook/sink/mode', '{"mode":"fail"}')->{code}, '200', 'mode fail');
    my $r = _req('POST', '/events', '{"payload":{"kind":"order.paid"}}');
    is($r->{code}, '202', 'accepted even on failure');
    my $d = _json($r);
    is($d->{state}, 'dead_letter', 'dead_letter');
    is($d->{attempts}, 3, 'tried max attempts');
    $j2 = $d->{id};
}

{
    my $d = _json(_req('GET', "/jobs/$j2"));
    is(scalar @{ $d->{attempts_log} }, 3, 'three attempts logged');
    is($d->{attempts_log}[0]{ok}, 0, 'attempt1 not ok');
    is($d->{attempts_log}[2]{status}, 500, 'last status 500');
    ok(!defined $d->{next_retry_at}, 'no retry left');
}

# 실패한 전송은 수신기에 남지 않음
is(_json(_req('GET', '/hook/sink'))->{count}, 1, 'failed sends not recorded');

# 디드레터 목록
{
    my $d = _json(_req('GET', '/dead-letters'));
    is($d->{count}, 1, 'one dead letter');
    is($d->{dead_letters}[0]{id}, $j2, 'dead letter id');
    is($d->{dead_letters}[0]{payload}{kind}, 'order.paid', 'dead letter payload');
}

# 디드레터 재전송
{
    is(_req('POST', '/hook/sink/mode', '{"mode":"ok"}')->{code}, '200', 'mode ok again');
    my $d = _json(_req('POST', "/dead-letters/$j2/retry"));
    is($d->{state}, 'delivered', 'retry delivered');
    is($d->{attempts}, 1, 'retry attempts');

    my $dl = _json(_req('GET', '/dead-letters'));
    is($dl->{count}, 0, 'dead letters drained');

    my $s = _json(_req('GET', '/hook/sink'));
    is($s->{count}, 2, 'sink now has 2');
}

# 입력 검증
is(_req('POST', '/events', '{}')->{code}, '400', 'missing payload 400');
is(_req('POST', '/events', '{"payload":"nope"}')->{code}, '400', 'payload must be object 400');
is(_req('GET', '/jobs/job-9999')->{code}, '404', 'unknown job 404');
is(_req('POST', '/dead-letters/job-9999/retry')->{code}, '404', 'unknown dead letter 404');
is(_req('POST', '/hook/sink/mode', '{"mode":"bogus"}')->{code}, '400', 'bad mode 400');

done_testing();
