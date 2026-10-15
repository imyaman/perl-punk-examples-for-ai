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

sub _get_full {
    my ($path, %hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "$_: $hdr{$_}" for sort keys %hdr;
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { headers => \%h, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

# 기본 요청: request id 자동 생성 + 응답 헤더 반영
{
    my $r = _get_full('/api/whoami');
    my $d = _json($r);
    like($d->{request_id}, qr/^req-\d+$/, 'auto-generated request id');
    is($r->{headers}{'x-request-id'}, $d->{request_id}, 'request id echoed in header');
}

# 클라이언트가 준 request id 는 그대로 사용
{
    my $r = _get_full('/api/whoami', 'X-Request-Id' => 'client-abc');
    my $d = _json($r);
    is($d->{request_id}, 'client-abc', 'client request id preserved');
    is($r->{headers}{'x-request-id'}, 'client-abc', 'client id echoed in header');
}

# after_dispatch 는 모든 응답에 적용
{
    my $r = _get_full('/api/ping');
    like($r->{headers}{'x-request-id'} // '', qr/^req-/, 'ping also gets header');
}

done_testing();
