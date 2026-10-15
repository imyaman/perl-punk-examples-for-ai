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
sub _get {
    my ($path, $key) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', "$BASE$path");
    push @cmd, '-H', "X-API-Key: $key" if defined $key;
    return _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200');

# 키 없음 -> 401
{
    my $r = _get('/api/admin/dashboard');
    is($r->{code}, '401', 'no key 401');
    is(_json($r)->{error}, 'api key required', 'no key message');
}

# 잘못된 키 -> 403
{
    my $r = _get('/api/admin/dashboard', 'wrong-key');
    is($r->{code}, '403', 'bad key 403');
}

# 올바른 키 -> 200
{
    my $r = _get('/api/admin/dashboard', 'secret-key');
    is($r->{code}, '200', 'good key 200');
    my $d = _json($r);
    is($d->{owner}, 'alice', 'guard stashed owner');
    is($d->{widgets}, 7, 'handler ran');
}

# 스코프의 다른 라우트도 보호됨
{
    is(_get('/api/admin/users')->{code}, '401', 'users no key 401');
    my $d = _json(_get('/api/admin/users', 'secret-key'));
    is_deeply($d->{users}, ['alice','bob','carol'], 'users with key');
}

done_testing();
