#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Time::HiRes ();

my $BASE = 'http://127.0.0.1:3004';

sub _run {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(20);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    if ($@) { return { body => '', code => '000' } }
    my ($body, $code) = $out =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}
sub _get { my ($p) = @_; _run('curl', '-s', '--max-time', '20', '-w', '\n%{http_code}', "$BASE$p") }
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200 (immediate)');

{
    my $t0 = Time::HiRes::time();
    my $r  = _get('/async/timer');
    my $dt = Time::HiRes::time() - $t0;
    is($r->{code}, '200', 'timer 200');
    is(_json($r)->{how}, 'timer', 'timer body');
    ok($dt >= 0.9, "timer delayed ~1s (got ${\(sprintf '%.2f', $dt)}s)");
}

{
    my $t0 = Time::HiRes::time();
    my $r  = _get('/async/promise');
    my $dt = Time::HiRes::time() - $t0;
    is($r->{code}, '200', 'promise 200');
    is(_json($r)->{how}, 'promise', 'promise body');
    ok($dt >= 0.9, "promise delayed ~1s (got ${\(sprintf '%.2f', $dt)}s)");
}

{
    my $r = _get('/async/await');
    is($r->{code}, '200', 'await 200');
    my $d = _json($r);
    is($d->{how}, 'await', 'await body');
    is($d->{value}, 42, 'await resolved value');
}

done_testing();
