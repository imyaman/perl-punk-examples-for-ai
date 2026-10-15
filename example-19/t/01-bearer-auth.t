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
    my ($path, $auth) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', "$BASE$path");
    push @cmd, '-H', "Authorization: $auth" if defined $auth;
    _run(@cmd);
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200 (public)');

{
    is(_get('/api/private/me')->{code}, '401', 'no auth 401');
}
{
    my $r = _get('/api/private/me', 'Bearer nope');
    is($r->{code}, '401', 'bad token 401');
    is(_json($r)->{error}, 'invalid token', 'bad token message');
}
{
    my $r = _get('/api/private/me', 'Bearer tok-alice');
    is($r->{code}, '200', 'good token 200');
    my $d = _json($r);
    is($d->{user}, 'alice', 'user resolved');
    is($d->{role}, 'admin', 'role resolved');
}
{
    my $r = _get('/api/private/secret', 'Bearer tok-bob');
    is($r->{code}, '200', 'secret with bob 200');
    is(_json($r)->{secret}, 'the answer is 42', 'secret body');
}

done_testing();
