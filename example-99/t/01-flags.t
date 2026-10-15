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
sub _j { JSON::PP->new->encode($_[0]) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 미정의 플래그
is(_req('GET', '/flags/nope')->{code}, '404', 'unknown flag 404');

# 100% 롤아웃
{
    is(_req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::true, rollout => 100 }))->{code}, '200', 'create flag');
    my $d = _json(_req('GET', '/flags/new-ui?key=u1'));
    ok($d->{enabled}, 'on at 100%');
    is($d->{reason}, 'rollout', 'reason rollout');
}

# 0% (enabled) -> off
{
    _req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::true, rollout => 0 }));
    my $d = _json(_req('GET', '/flags/new-ui?key=u1'));
    ok(!$d->{enabled}, 'off at 0%');
    is($d->{reason}, 'not_in_rollout', 'reason not_in_rollout');
}

# enabled=false 이면 rollout 무관 off
{
    _req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::false, rollout => 100 }));
    my $d = _json(_req('GET', '/flags/new-ui?key=u1'));
    ok(!$d->{enabled}, 'disabled wins');
    is($d->{reason}, 'disabled', 'reason disabled');
}

# 50%: 같은 키는 항상 같은 결과, 여러 키는 섞임
{
    _req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::true, rollout => 50 }));
    my $first = _json(_req('GET', '/flags/new-ui?key=stable'))->{enabled};
    my $again = _json(_req('GET', '/flags/new-ui?key=stable'))->{enabled};
    is($first, $again, 'deterministic for same key');
    my ($on, $off) = (0, 0);
    for my $i (1 .. 40) {
        _json(_req('GET', "/flags/new-ui?key=user$i"))->{enabled} ? $on++ : $off++;
    }
    ok($on > 0 && $off > 0, "50% splits traffic (on=$on off=$off)");
}

# 개별 override: 강제 ON / OFF
{
    _req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::true, rollout => 0 }));
    is(_req('POST', '/flags/new-ui/override', _j({ key => 'vip', enabled => JSON::PP::true }))->{code}, '200', 'override on');
    my $d = _json(_req('GET', '/flags/new-ui?key=vip'));
    ok($d->{enabled}, 'override forces on');
    is($d->{reason}, 'override', 'reason override');

    _req('PUT', '/flags/new-ui', _j({ enabled => JSON::PP::true, rollout => 100 }));
    _req('POST', '/flags/new-ui/override', _j({ key => 'blocked', enabled => JSON::PP::false }));
    ok(!_json(_req('GET', '/flags/new-ui?key=blocked'))->{enabled}, 'override forces off');
}

# 목록
{
    my $d = _json(_req('GET', '/flags'));
    is($d->{count}, 1, 'one flag');
    is($d->{flags}[0]{name}, 'new-ui', 'flag name');
    is($d->{flags}[0]{overrides}, 2, 'override count');
}

# 검증
is(_req('GET', '/flags/other')->{code}, '404', 'unknown 404');
is(_req('PUT', '/flags/x', _j({ enabled => JSON::PP::true, rollout => 101 }))->{code}, '400', 'rollout 101 400');
is(_req('PUT', '/flags/x', _j({ rollout => 10 }))->{code}, '400', 'enabled required 400');
is(_req('POST', '/flags/unknown/override', _j({ key => 'a', enabled => JSON::PP::true }))->{code}, '404', 'override unknown 404');

done_testing();
