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
sub _ev { my ($type, $ts) = @_;
    return _json(_req('POST', '/events', JSON::PP->new->encode({ type => $type, ts => $ts })));
}

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 이벤트 5개 (ts 를 명시해 결정적으로)
my @ts = (1000, 1000, 2000, 3000, 3000);
for my $i (0 .. 4) {
    my $e = _ev("t$i", $ts[$i]);
    is($e->{id}, $i + 1, "event id ".($i+1));
    is($e->{ts}, $ts[$i], "event ts");
}

# 전체
{
    my $d = _json(_req('GET', '/feed'));
    is($d->{count}, 5, 'all 5');
    is_deeply([map { $_->{id} } @{ $d->{events} }], [1, 2, 3, 4, 5], 'id order');
    ok(!$d->{has_more}, 'no more');
    ok(!defined $d->{next_cursor}, 'no cursor');
}

# 커서 페이지네이션
{
    my $p1 = _json(_req('GET', '/feed?limit=2'));
    is_deeply([map { $_->{id} } @{ $p1->{events} }], [1, 2], 'page1');
    ok($p1->{has_more}, 'has more');
    my $cursor = $p1->{next_cursor};
    ok(defined $cursor, 'cursor present');

    my $p2 = _json(_req('GET', "/feed?limit=2&cursor=$cursor"));
    is_deeply([map { $_->{id} } @{ $p2->{events} }], [3, 4], 'page2');

    my $p3 = _json(_req('GET', "/feed?limit=2&cursor=$p2->{next_cursor}"));
    is_deeply([map { $_->{id} } @{ $p3->{events} }], [5], 'page3');
    ok(!$p3->{has_more}, 'end');
    ok(!defined $p3->{next_cursor}, 'no cursor at end');
}

# since / until 창 (경계 포함)
{
    my $d = _json(_req('GET', '/feed?since=1000&until=2000'));
    is_deeply([map { $_->{id} } @{ $d->{events} }], [1, 2, 3], 'window 1000..2000');
}
{
    my $d = _json(_req('GET', '/feed?since=3000'));
    is_deeply([map { $_->{id} } @{ $d->{events} }], [4, 5], 'since 3000');
}
{
    my $d = _json(_req('GET', '/feed?until=1000'));
    is_deeply([map { $_->{id} } @{ $d->{events} }], [1, 2], 'until 1000');
}
{
    my $d = _json(_req('GET', '/feed?since=5000'));
    is($d->{count}, 0, 'empty window');
}

# 창 + 커서 조합
{
    my $p1 = _json(_req('GET', '/feed?since=1000&limit=2'));
    is_deeply([map { $_->{id} } @{ $p1->{events} }], [1, 2], 'window page1');
    my $p2 = _json(_req('GET', "/feed?since=1000&limit=2&cursor=$p1->{next_cursor}"));
    is_deeply([map { $_->{id} } @{ $p2->{events} }], [3, 4], 'window page2');
}

# 단건
is(_req('GET', '/events/3')->{code}, '200', 'single event');
is(_json(_req('GET', '/events/3'))->{type}, 't2', 'event type');
is(_req('GET', '/events/999')->{code}, '404', 'missing event 404');

# 검증
is(_req('GET', '/feed?limit=0')->{code}, '400', 'limit 0 400');
is(_req('GET', '/feed?limit=1000')->{code}, '400', 'limit too big 400');
is(_req('GET', '/feed?limit=abc')->{code}, '400', 'limit non-numeric 400');
is(_req('GET', '/feed?since=abc')->{code}, '400', 'since non-numeric 400');
is(_req('GET', '/feed?cursor=!!!')->{code}, '400', 'bad cursor 400');
is(_req('POST', '/events', '{}')->{code}, '400', 'type required 400');

done_testing();
