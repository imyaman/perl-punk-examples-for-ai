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
sub _get { my ($p) = @_; _run('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', "$BASE$p") }
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200');

{
    my $d = _json(_get('/api/v1/status'));
    is($d->{version}, 'v1', 'v1 status version');
    is($d->{status}, 'live', 'v1 status live');
}
{
    my $d = _json(_get('/api/v1/items'));
    is_deeply($d->{items}, ['alpha', 'beta'], 'v1 items');
}
{
    my $d = _json(_get('/api/v2/status'));
    is($d->{version}, 'v2', 'v2 status version');
    is_deeply($d->{features}, ['pagination'], 'v2 features');
}
{
    my $d = _json(_get('/api/v1/admin/stats'));
    is($d->{scope}, 'admin', 'nested scope admin');
    is($d->{users}, 3, 'nested scope users');
}
{
    is(_get('/api/v3/status')->{code}, '404', 'unknown prefix 404');
    is(_get('/api/v1/unknown')->{code}, '404', 'unknown path in scope 404');
}

done_testing();
