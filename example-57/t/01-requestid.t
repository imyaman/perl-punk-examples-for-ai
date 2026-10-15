#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

sub _raw {
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
sub _full {
    my ($path, $rid) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "X-Request-Id: $rid" if defined $rid;
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('/api/ping')->{code}, '200', 'ping 200');

# 자동 생성
{
    my $r = _full('/whoami');
    my $rid = $r->{headers}{'x-request-id'};
    ok($rid && $rid =~ /^[0-9a-f]{32}$/, 'generated request id');
    is(_json($r)->{request_id}, $rid, 'body matches header');
}

# 들어온 값 유지
{
    my $r = _full('/whoami', 'my-correlation-42');
    is($r->{headers}{'x-request-id'}, 'my-correlation-42', 'incoming id echoed');
    is(_json($r)->{request_id}, 'my-correlation-42', 'body matches incoming');
}

# 유효하지 않은 값은 새로 생성
{
    my $r = _full('/whoami', "bad\nid");
    my $rid = $r->{headers}{'x-request-id'} // '';
    ok($rid =~ /^[0-9a-f]{32}$/, 'invalid id replaced');
}

# 여러 요청은 서로 다른 id
{
    my $a = _full('/whoami')->{headers}{'x-request-id'};
    my $b = _full('/whoami')->{headers}{'x-request-id'};
    isnt($a, $b, 'unique per request');
}

done_testing();
