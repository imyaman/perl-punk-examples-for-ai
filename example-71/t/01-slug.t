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
sub _req {
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

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 자동 슬러그
{
    my $r = _req('POST', '/posts', '{"title":"Hello World!"}');
    is($r->{code}, '201', 'create 201');
    is(_json($r)->{slug}, 'hello-world', 'slugified');
    like($r->{headers}{location} // '', qr{/posts/hello-world}, 'location');
}

# 같은 제목 -> -2 자동
{
    my $r = _req('POST', '/posts', '{"title":"Hello World!"}');
    is(_json($r)->{slug}, 'hello-world-2', 'unique suffix');
}

# 다시 -> -3
{
    my $r = _req('POST', '/posts', '{"title":"Hello World!"}');
    is(_json($r)->{slug}, 'hello-world-3', 'unique suffix 3');
}

# 명시 슬러그 중복 -> 409
{
    my $r = _req('POST', '/posts', '{"title":"Other","slug":"hello-world"}');
    is($r->{code}, '409', 'conflict 409');
    like(_json($r)->{title} // '', qr/Conflict/, 'problem title');
}

# 명시 슬러그 정상
{
    my $r = _req('POST', '/posts', '{"title":"Special","slug":"My Slug"}');
    is($r->{code}, '201', 'explicit slug 201');
    is(_json($r)->{slug}, 'my-slug', 'explicit slugified');
}

# 조회
{
    my $r = _req('GET', '/posts/hello-world');
    is($r->{code}, '200', 'get 200');
    is(_json($r)->{title}, 'Hello World!', 'title');
    is(_req('GET', '/posts/nope')->{code}, '404', 'missing 404');
}

# 제목 없음
is(_req('POST', '/posts', '{}')->{code}, '400', 'no title 400');

done_testing();
