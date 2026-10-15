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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET','/api/ping')->{code}, '200', 'ping 200');

# 알 수 없는 파일
is(_full('POST', '/links', '{"name":"nope"}')->{code}, '404', 'unknown file 404');

# 정상 링크 생성
my $url;
{
    my $r = _full('POST', '/links', '{"name":"report.pdf","ttl":3600}');
    is($r->{code}, '201', 'create 201');
    $url = _json($r)->{url};
    like($url // '', qr{^/dl/report\.pdf\?exp=\d+&sig=[0-9a-f]+$}, 'signed url shape');
}

# 정상 다운로드
{
    my $r = _full('GET', $url);
    is($r->{code}, '200', 'download 200');
    like($r->{headers}{'content-disposition'} // '', qr/report\.pdf/, 'disposition');
    like($r->{body}, qr/PDF-DATA-REPORT/, 'content');
}

# 서명 위조 -> 403
{
    my ($bad) = $url =~ s/sig=[0-9a-f]+/sig=deadbeef/r;
    is(_full('GET', $bad)->{code}, '403', 'tampered 403');
}

# 서명 없음 -> 403
{
    my ($nosig) = $url =~ s/&sig=[0-9a-f]+//r;
    is(_full('GET', $nosig)->{code}, '403', 'missing sig 403');
}

# 만료 (ttl=1 후 2초 대기) -> 410
{
    my $r = _full('POST', '/links', '{"name":"image.png","ttl":1}');
    my $u = _json($r)->{url};
    is(_full('GET', $u)->{code}, '200', 'fresh link 200');
    sleep 2;
    is(_full('GET', $u)->{code}, '410', 'expired 410');
}

done_testing();
