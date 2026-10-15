#!/usr/bin/perl
use Test::More;
use JSON::PP;

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
    return $@ ? '' : $out;
}

is(_run('curl', '-s', '--max-time', '10', '-w', '\n%{http_code}', "$BASE/api/ping")
    =~ /200\z/ ? 1 : 0, 1, 'ping 200');

my $out = _run('curl', '-sN', '--max-time', '10', '-i', "$BASE/events");
my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
$body //= '';

like($head // '', qr{Content-Type:\s*text/event-stream}i, 'SSE content-type');

my @data = ($body =~ /^data:\s*(.+)$/mg);
is(scalar @data, 3, 'received 3 events');

my $first = eval { JSON::PP->new->decode($data[0]) };
ok($first && $first->{seq} == 1, 'first event seq=1');

like($body, qr/^id:\s*3$/m, 'id field written');
my $last = eval { JSON::PP->new->decode($data[-1]) };
ok($last && $last->{seq} == 3, 'last event seq=3');

done_testing();
