#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Fetch;

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
    return $@ ? '' : $out;
}

like(_run('curl', '-s', '--max-time', '10', '-o', '/dev/null', '-w', '%{http_code}', "$BASE/api/ping"),
     qr/^200$/, 'ping 200');

my $ua = Fetch->new(timeout => 10);

my $ws = eval { $ua->websocket('ws://127.0.0.1:3004/ws/echo')->get };
ok($ws, 'websocket handshake') or diag("connect failed: $@");

SKIP: {
    skip 'no websocket connection', 3 unless $ws;

    my $welcome = eval { $ws->next_message->get };
    is($welcome, 'welcome', 'open message received');

    $ws->send('hello');
    my $reply = eval { $ws->next_message->get };
    is($reply, 'echo:hello', 'echo reply');

    $ws->send('world');
    my $reply2 = eval { $ws->next_message->get };
    is($reply2, 'echo:world', 'second echo reply');

    $ws->close;
}

done_testing();
