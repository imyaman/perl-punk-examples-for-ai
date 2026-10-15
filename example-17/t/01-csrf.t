#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';
my $JAR  = "/tmp/punk-csrf-$$.txt";
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
sub _call {
    my ($method, $path, %o) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-c', $JAR, '-b', $JAR,
               '-w', '\n%{http_code}', '-X', $method, "$BASE$path");
    push @cmd, '-H', "X-CSRF-Token: $o{token}" if defined $o{token};
    push @cmd, '-d', $o{data} if defined $o{data};
    _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_call('GET', '/api/ping')->{code}, '200', 'ping 200');

# 토큰 발급
my $token;
{
    my $r = _call('GET', '/api/token');
    is($r->{code}, '200', 'token 200');
    $token = _json($r)->{csrf_token};
    ok(defined $token && length $token, 'token returned');
}

# 토큰 없이 POST -> 403
{
    my $r = _call('POST', '/api/action', data => 'x=1');
    is($r->{code}, '403', 'post without token 403');
}

# 올바른 토큰으로 POST -> 200 (토큰 소비)
{
    my $r = _call('POST', '/api/action', token => $token, data => 'x=1');
    is($r->{code}, '200', 'post with token 200');
    is(_json($r)->{did}, 'action', 'action ran');
}

# 같은 토큰 재사용 -> 403 (일회용)
{
    my $r = _call('POST', '/api/action', token => $token, data => 'x=1');
    is($r->{code}, '403', 'reused token 403');
}

done_testing();
