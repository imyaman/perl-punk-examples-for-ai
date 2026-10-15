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
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
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

is(_full('/api/ping')->{code}, '200', 'ping 200');

# meta
{
    my $d = _json(_full('/images/1'));
    is($d->{ext}, 'jpg', 'ext jpg');
}

# raw jpg
{
    my $r = _full('/images/1/raw');
    is($r->{code}, '200', 'jpg raw 200');
    like($r->{headers}{'content-type'} // '', qr/image\/jpeg/, 'image/jpeg');
    ok(defined $r->{headers}{'content-length'}, 'has cl');
    is($r->{body}, 'FAKEJPEGDATA123', 'raw bytes match');
}

# raw png
{
    my $r = _full('/images/2/raw');
    is($r->{code}, '200', 'png raw 200');
    like($r->{headers}{'content-type'} // '', qr/image\/png/, 'image/png');
    is($r->{body}, 'FAKEPNGGDATA456', 'png bytes');
}

# 404
{
    my $r = _full('/images/99/raw');
    is($r->{code}, '404', 'raw 404');
}

done_testing();
