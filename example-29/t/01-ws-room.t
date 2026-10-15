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

my $a = eval { $ua->websocket('ws://127.0.0.1:3004/ws/chat')->get };
ok($a, 'client A connected') or diag($@);
my $b = eval { $ua->websocket('ws://127.0.0.1:3004/ws/chat')->get };
ok($b, 'client B connected') or diag($@);

SKIP: {
    skip 'no connections', 4 unless $a && $b;

    is(eval { $a->next_message->get }, 'joined:1', 'A sees joined:1');
    is(eval { $b->next_message->get }, 'joined:2', 'B sees joined:2');

    # A 가 보내면 B 가 받는다 (보낸 사람 제외)
    $a->send('hello-from-A');
    is(eval { $b->next_message->get }, 'hello-from-A', 'B received A message');

    # B 가 보내면 A 가 받는다
    $b->send('hi-from-B');
    is(eval { $a->next_message->get }, 'hi-from-B', 'A received B message');

    $a->close;
    $b->close;
}

done_testing();
