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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "If-Modified-Since: $h{ims}" if $h{ims};
    if ($h{body}) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $h{body};
    }
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

my $lm;
{
    my $r = _req('GET', '/page');
    is($r->{code}, '200', 'first get 200');
    $lm = $r->{headers}{'last-modified'};
    like($lm // '', qr/GMT$/, 'Last-Modified present');
    is(_json($r)->{content}, 'hello world', 'content');
}

# 같은 시각으로 If-Modified-Since -> 304
{
    my $r = _req('GET', '/page', ims => $lm);
    is($r->{code}, '304', 'not modified 304');
    is($r->{body}, '', 'empty body on 304');
}

# 과거 시각 문자열 -> 200
{
    my $r = _req('GET', '/page', ims => 'Thu, 01 Jan 1970 00:00:00 GMT');
    is($r->{code}, '200', 'stale ims 200');
}

# PUT 후 새로운 Last-Modified
my $lm2;
{
    my $r = _req('PUT', '/page', body => '{"content":"updated"}');
    is($r->{code}, '200', 'put 200');
    $lm2 = $r->{headers}{'last-modified'};
    isnt($lm2, $lm, 'last-modified changed');
}

# 이전 lm 으로는 200
{
    my $r = _req('GET', '/page', ims => $lm);
    is($r->{code}, '200', 'old ims -> 200 after update');
    is(_json($r)->{content}, 'updated', 'updated content');
}

# 새 lm 으로는 304
is(_req('GET', '/page', ims => $lm2)->{code}, '304', 'new ims -> 304');

done_testing();
