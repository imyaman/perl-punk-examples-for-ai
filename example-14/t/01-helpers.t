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
    my $r = _get('/api/time');
    is($r->{code}, '200', 'time 200');
    my $d = _json($r);
    like($d->{now}, qr/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/, 'helper now_iso format');
    is($d->{source}, 'helper', 'helper source');
}

{
    my $r = _get('/api/sum/2/3');
    is($r->{code}, '200', 'sum 200');
    my $d = _json($r);
    is($d->{sum}, 5, 'sum helper adds route params');
    is($d->{a}, '2', 'param a passed through');
}

{
    my $d = _json(_get('/api/sum/10/20'));
    is($d->{sum}, 30, 'sum helper again');
}

done_testing();
