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
    my ($path, $tp) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, ('-H', "traceparent: $tp") if defined $tp;
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

is(_req('/api/ping')->{code}, '200', 'ping 200');

# 헤더 없음 -> 새 트레이스 시작
{
    my $r = _req('/traced');
    is($r->{code}, '200', 'no header 200');
    my $d = _json($r);
    like($d->{trace_id}, qr/^[0-9a-f]{32}$/, 'trace id 32 hex');
    like($d->{span_id},  qr/^[0-9a-f]{16}$/, 'span id 16 hex');
    ok(!defined $d->{parent_span_id}, 'no parent');
    ok($d->{sampled}, 'sampled default');
    ok(!$d->{restarted}, 'not restarted when absent');
    ok($r->{headers}{traceparent}, 'response traceparent header');
    like($r->{headers}{traceparent}, qr/^00-[0-9a-f]{32}-[0-9a-f]{16}-01$/, 'header format');
}

# 유효한 헤더 -> 이어받음
{
    my $trace = 'a' x 32;
    my $span  = 'b' x 16;
    my $r = _req('/traced', "00-$trace-$span-01");
    my $d = _json($r);
    is($d->{trace_id}, $trace, 'trace id propagated');
    is($d->{parent_span_id}, $span, 'parent span = incoming span');
    isnt($d->{span_id}, $span, 'new span id');
    ok($d->{sampled}, 'sampled');
    ok(!$d->{restarted}, 'not restarted');
}

# sampled flag 00
{
    my $r = _req('/traced', '00-' . ('c' x 32) . '-' . ('d' x 16) . '-00');
    ok(!_json($r)->{sampled}, 'sampled false');
    like($r->{headers}{traceparent}, qr/-00$/, 'response flag 00');
}

# 잘못된 헤더 -> 재시작
{
    my $r = _req('/traced', 'garbage');
    my $d = _json($r);
    ok($d->{restarted}, 'restarted on invalid');
    like($d->{trace_id}, qr/^[0-9a-f]{32}$/, 'fresh trace id');
}

# all-zero trace id -> 재시작
{
    my $r = _req('/traced', '00-' . ('0' x 32) . '-' . ('b' x 16) . '-01');
    ok(_json($r)->{restarted}, 'all-zero id restarted');
}

# 버전 ff -> 재시작
{
    my $r = _req('/traced', 'ff-' . ('a' x 32) . '-' . ('b' x 16) . '-01');
    ok(_json($r)->{restarted}, 'bad version restarted');
}

done_testing();
