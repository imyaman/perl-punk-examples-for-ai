#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';
my $JAR  = "/tmp/punk-cookie-$$.txt";
unlink $JAR;
END { unlink $JAR }

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
# jar 유지하며 요청, 헤더/본문 모두 반환
sub _call {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-c', $JAR, '-b', $JAR, '-i',
                   "$BASE$path");
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { headers => \%h, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_call('/api/ping')->{body} =~ /pong/ ? 1 : 0, 1, 'ping ok');

# 쿠키가 아직 없음
{
    my $d = _json(_call('/cookie/read'));
    is($d->{present}, 0, 'no cookie yet');
}

# 설정: Set-Cookie 헤더
{
    my $r = _call('/cookie/set');
    my $d = _json($r);
    is($d->{set}, 1, 'set response');
    like($r->{headers}{'set-cookie'} // '', qr/daeha=tasty/, 'Set-Cookie header');
}

# jar 로 이어서 읽기
{
    my $d = _json(_call('/cookie/read'));
    is($d->{present}, 1, 'cookie present');
    is($d->{value}, 'tasty', 'cookie value');
}

# 삭제
{
    my $r = _call('/cookie/clear');
    is(_json($r)->{cleared}, 1, 'clear response');
}
{
    my $d = _json(_call('/cookie/read'));
    is($d->{present}, 0, 'cookie gone after clear');
}

done_testing();
