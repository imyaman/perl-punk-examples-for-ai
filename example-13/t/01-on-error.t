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
    my $r = _get('/api/ok');
    is($r->{code}, '200', 'ok 200');
    is(_json($r)->{ok}, 1, 'ok body');
}

{
    my $r = _get('/api/boom');
    is($r->{code}, '500', 'boom 500');
    my $d = _json($r);
    is($d->{error}{code}, 'INTERNAL', 'custom error code');
    like($d->{error}{message}, qr/kaboom/, 'custom error message');
}

done_testing();
