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
    my ($method, $path, %o) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "$_: $o{headers}{$_}" for sort keys %{ $o{headers} || {} };
    push @cmd, '--data-raw', $o{body} if defined $o{body};
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

my $etag;
{
    my $r = _full('GET', '/resource');
    is($r->{code}, '200', 'first GET 200');
    $etag = $r->{headers}{etag};
    ok($etag, 'ETag header present');
    is(_json($r)->{text}, 'hello', 'body text');
}

# 같은 ETag 로 조건부 GET -> 304
{
    my $r = _full('GET', '/resource', headers => { 'If-None-Match' => $etag });
    is($r->{code}, '304', 'conditional GET 304');
    is($r->{body}, '', '304 has empty body');
}

# 갱신 -> 새 ETag
my $etag2;
{
    my $r = _full('PUT', '/resource', body => '{"text":"world"}');
    is($r->{code}, '200', 'PUT 200');
    $etag2 = $r->{headers}{etag} // _json($r)->{etag};
    isnt($etag2, $etag, 'new ETag differs');
    is(_json($r)->{text}, 'world', 'updated body');
}

# 옛 ETag 는 이제 통하지 않음 -> 200
{
    my $r = _full('GET', '/resource', headers => { 'If-None-Match' => $etag });
    is($r->{code}, '200', 'stale ETag -> 200');
    is(_json($r)->{text}, 'world', 'fresh body');
}

# 새 ETag -> 304
{
    my $r = _full('GET', '/resource', headers => { 'If-None-Match' => $etag2 });
    is($r->{code}, '304', 'fresh ETag -> 304');
}

done_testing();
