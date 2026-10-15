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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "If-Match: $h{ifmatch}" if exists $h{ifmatch};
    push @cmd, '-H', 'Content-Type: application/json';
    push @cmd, '--data-raw', $h{body} if defined $h{body};
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %hdr;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $hdr{lc $1} = $2;
    }
    return { code => $code, headers => \%hdr, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

my $etag;
{
    my $r = _full('GET', '/doc');
    is($r->{code}, '200', 'get doc');
    $etag = $r->{headers}{etag};
    ok($etag, 'etag present');
}

# If-Match 누락 -> 428
is(_full('PUT', '/doc', body => '{"text":"x"}')->{code}, '428', 'missing If-Match 428');

# 잘못된 If-Match -> 412
is(_full('PUT', '/doc', ifmatch => '"stale"', body => '{"text":"x"}')->{code}, '412', 'stale If-Match 412');

# 올바른 If-Match -> 200, 새 ETag
my $etag2;
{
    my $r = _full('PUT', '/doc', ifmatch => $etag, body => '{"text":"version-2"}');
    is($r->{code}, '200', 'valid If-Match 200');
    $etag2 = $r->{headers}{etag};
    isnt($etag2, $etag, 'etag changed');
    is(_json($r)->{text}, 'version-2', 'text updated');
}

# 이전 ETag 로 다시 시도 -> 412
is(_full('PUT', '/doc', ifmatch => $etag, body => '{"text":"z"}')->{code}, '412', 'old etag now 412');

# 와일드카드 *
is(_full('PUT', '/doc', ifmatch => '*', body => '{"text":"version-3"}')->{code}, '200', 'wildcard ok');

done_testing();
