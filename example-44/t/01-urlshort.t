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
    my ($method, $path) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
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

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# 잘못된 url
is(_full('GET', '/shorten?url=noturl')->{code}, '400', 'bad url 400');

# 생성
my $r = _full('GET', '/shorten?url=http://example.com/foo');
is($r->{code}, '200', 'shorten 200');
my $d = _json($r);
like($d->{short}, qr|^/s\d+$|, 'short format');
is($d->{url}, 'http://example.com/foo', 'url preserved');

# 리다이렉트
my $r2 = _full('GET', $d->{short});
is($r2->{code}, '302', 'redirect 302');
like($r2->{headers}{location} // '', qr|^http://example\.com/foo|, 'location');

# 없는 코드 404
is(_full('GET', '/s999999')->{code}, '404', 'unknown 404');

done_testing();
