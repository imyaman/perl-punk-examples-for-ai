#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

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
sub _req {
    my ($method, $path) = @_;
    _run('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', '-X', $method, "$BASE$path");
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_req('GET', '/api/ping')->{code}, '200', 'ping 200');

# 마운트된 PSGI 앱이 응답
{
    my $r = _req('GET', '/legacy/hello');
    is($r->{code}, '200', 'legacy 200');
    my $d = _json($r);
    is($d->{legacy}, 1, 'legacy app answered');
    is($d->{path}, '/hello', 'prefix stripped from PATH_INFO');
    is($d->{method}, 'GET', 'method forwarded');
}

# 메서드도 그대로 전달
{
    my $d = _json(_req('POST', '/legacy/things/1'));
    is($d->{method}, 'POST', 'legacy POST forwarded');
    is($d->{path}, '/things/1', 'legacy nested path');
}

# 다른 경로는 Punk 라우트가 처리
{
    is(_req('GET', '/legacyx')->{code}, '404', 'longer prefix not mounted');
}

done_testing();
