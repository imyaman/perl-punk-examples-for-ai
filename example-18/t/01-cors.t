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
    my ($method, $path, %hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "$_: $hdr{$_}" for sort keys %hdr;
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

my $OK = 'https://app.example.com';

# 프리플라이트(OPTIONS) 자동 응답
{
    my $r = _full('OPTIONS', '/api/data',
        'Origin' => $OK,
        'Access-Control-Request-Method' => 'GET');
    like($r->{code}, qr/^2\d\d$/, 'preflight 2xx');
    is($r->{headers}{'access-control-allow-origin'}, $OK, 'ACAO echoed origin');
    is($r->{headers}{'access-control-allow-credentials'}, 'true', 'credentials allowed');
    like($r->{headers}{'access-control-allow-methods'} // '', qr/GET/, 'methods include GET');
}

# 실제 요청에도 CORS 헤더
{
    my $r = _full('GET', '/api/data', 'Origin' => $OK);
    is($r->{code}, '200', 'data 200');
    is($r->{headers}{'access-control-allow-origin'}, $OK, 'ACAO on real response');
    like($r->{headers}{'access-control-expose-headers'} // '', qr/X-Request-Id/, 'expose header');
}

# 허용되지 않은 오리진은 ACAO 없음
{
    my $r = _full('GET', '/api/data', 'Origin' => 'https://evil.example.com');
    is($r->{headers}{'access-control-allow-origin'}, undef, 'no ACAO for other origin');
}

done_testing();
