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
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
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

{
    my $r = _full('GET', '/fail/400');
    is($r->{code}, '400', '400');
    like($r->{headers}{'content-type'} // '', qr/problem\+json/, 'problem+json');
    my $d = _json($r);
    is($d->{status}, 400, 'status in body');
    is($d->{title} // '', 'Bad Request', 'title');
}

{
    my $r = _full('POST', '/fail/404');
    is($r->{code}, '404', '404');
    like($r->{headers}{'content-type'} // '', qr/problem\+json/, 'problem+json 404');
    my $d = _json($r);
    is($d->{status}, 404, 'status 404 body');
    is($d->{detail} // '', 'resource does not exist', 'detail');
}

{
    my $r = _full('GET', '/fail/422');
    is($r->{code}, '422', '422');
    my $d = _json($r);
    is($d->{status}, 422, 'status 422');
    is(ref $d->{errors}, 'ARRAY', 'errors array');
}

done_testing();
