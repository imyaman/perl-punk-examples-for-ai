#!/usr/bin/perl
use Test::More;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

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
sub _req {
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (exists $h{body}) {
        push @cmd, '-H', 'Content-Type: ' . ($h{ct} // 'application/octet-stream');
        push @cmd, '--data-binary', $h{body};
    }
    push @cmd, '-H', "If-None-Match: $h{inm}" if defined $h{inm};
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

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

my $data = 'hello blob';
my $id = sha256_hex($data);

# 최초 저장 -> 201
{
    my $r = _req('POST', '/blobs', body => $data);
    is($r->{code}, '201', 'store 201');
    is(_json($r)->{id}, $id, 'id is sha256');
    is(_json($r)->{size}, length($data), 'size');
    is(_json($r)->{deduplicated}, 0, 'not dedup');
    is($r->{headers}{etag}, "\"$id\"", 'etag');
}

# 같은 내용 -> 200 dedup
{
    my $r = _req('POST', '/blobs', body => $data);
    is($r->{code}, '200', 'dedup 200');
    is(_json($r)->{deduplicated}, 1, 'deduplicated flag');
    is(_json($r)->{id}, $id, 'same id');
}

# 조회
{
    my $r = _req('GET', "/blobs/$id", ct => 'application/json');
    is($r->{code}, '200', 'get 200');
    is($r->{body}, $data, 'content matches');
    is($r->{headers}{etag}, "\"$id\"", 'etag on get');
}

# 조건부 GET 304
{
    my $r = _req('GET', "/blobs/$id", inm => "\"$id\"");
    is($r->{code}, '304', 'conditional 304');
    is($r->{body}, '', 'empty 304');
}

# 메타
{
    my $r = _req('GET', "/blobs/$id/meta");
    is($r->{code}, '200', 'meta 200');
    is(_json($r)->{size}, length($data), 'meta size');
}

# 없는 blob
is(_req('GET', '/blobs/deadbeef')->{code}, '404', 'missing 404');

# 빈 본문
is(_req('POST', '/blobs', body => '')->{code}, '400', 'empty 400');

done_testing();
