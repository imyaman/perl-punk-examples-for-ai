#!/usr/bin/perl
use Test::More;
use JSON::PP;
use IO::Socket::INET;
use POSIX ();

my $BASE     = 'http://127.0.0.1:3004';
my $UP_PORT  = 3029;

# ---- 가짜 업스트림 서버 (자식 프로세스) ----
my $upstream_pid;
sub _start_upstream {
    my $pid = fork();
    if (!defined $pid) { die "fork: $!" }
    if ($pid == 0) {
        open(STDOUT, '>', '/dev/null');
        open(STDERR, '>', '/dev/null');
        my $srv = IO::Socket::INET->new(
            LocalAddr => '127.0.0.1',
            LocalPort => $UP_PORT,
            Listen    => 5,
            ReuseAddr => 1,
            Proto     => 'tcp',
        ) or POSIX::_exit(1);
        while (my $conn = $srv->accept) {
            my $req = '';
            while (my $line = <$conn>) {
                $req .= $line;
                last if $line =~ /^\r?\n$/;
            }
            my $body = '{"upstream":"ok","greeting":"hello"}';
            print $conn "HTTP/1.1 200 OK\r\n"
                      . "Content-Type: application/json\r\n"
                      . "Content-Length: " . length($body) . "\r\n"
                      . "Connection: close\r\n\r\n"
                      . $body;
            close $conn;
        }
        POSIX::_exit(0);
    }
    $upstream_pid = $pid;
    return $pid;
}
END { kill 'TERM', $upstream_pid if $upstream_pid }

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

_start_upstream();
select undef, undef, undef, 0.3;   # 리슨 준비 대기

is(_get('/api/ping')->{code}, '200', 'ping 200');

{
    my $r = _get('/api/upstream');
    is($r->{code}, '200', 'upstream call 200');
    my $d = _json($r);
    is($d->{status}, 200, 'upstream status passed through');
    is($d->{content_type}, 'application/json', 'upstream content-type');
    is($d->{body}{upstream}, 'ok', 'upstream body decoded');
    is($d->{body}{greeting}, 'hello', 'upstream body field');
}

done_testing();
