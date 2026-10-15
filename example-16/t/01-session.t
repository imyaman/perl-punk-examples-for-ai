#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';
my $JAR  = "/tmp/punk-session-$$.txt";
unlink $JAR;
END { unlink $JAR }

sub _run {
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
    if ($@) { return { body => '', code => '000' }; }
    my ($body, $code) = $out =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}
# 모든 호출에 쿠키 jar 를 붙여 세션을 이어간다
sub _call {
    my ($method, $path, $data) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-c', $JAR, '-b', $JAR,
               '-w', '\n%{http_code}', '-X', $method, "$BASE$path");
    push @cmd, '-d', $data if defined $data;
    _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_call('GET', '/api/ping')->{code}, '200', 'ping 200');

# 세션 없음 -> 401
is(_call('GET', '/api/me')->{code}, '401', 'me without session 401');

# 로그인
{
    my $r = _call('POST', '/api/login', 'user=alice');
    is($r->{code}, '200', 'login 200');
    is(_json($r)->{logged_in}, 1, 'login body');
}

# 세션 쿠키로 조회
{
    my $r = _call('GET', '/api/me');
    is($r->{code}, '200', 'me 200 after login');
    is(_json($r)->{user}, 'alice', 'session carried user');
}

# 로그아웃
{
    my $r = _call('POST', '/api/logout');
    is($r->{code}, '200', 'logout 200');
    is(_json($r)->{logged_out}, 1, 'logout body');
}
{
    is(_call('GET', '/api/me')->{code}, '401', 'me 401 after logout');
}

done_testing();
