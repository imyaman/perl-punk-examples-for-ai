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
    my ($path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "Accept: $h{accept}" if $h{accept};
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %hdr;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $hdr{lc $1} = $2;
    }
    return { code => $code, headers => \%hdr, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('/api/ping')->{code}, '200', 'ping 200');

# URL prefix
{
    my $d = _json(_full('/v1/items'));
    ok(exists $d->{items}, 'v1 has items');
    ok(!exists $d->{data}, 'v1 no data');
}
{
    my $d = _json(_full('/v2/items'));
    ok(exists $d->{data}, 'v2 has data');
    is($d->{meta}{version}, 2, 'v2 meta version');
}

# Accept header
{
    my $r = _full('/items', accept => 'application/vnd.daeha.v2+json');
    my $d = _json($r);
    ok(exists $d->{data}, 'v2 via accept');
    like($r->{headers}{'content-type'} // '', qr/vnd\.daeha\.v2\+json/, 'v2 content-type');
}
{
    my $r = _full('/items', accept => 'application/vnd.daeha.v1+json');
    my $d = _json($r);
    ok(exists $d->{items}, 'v1 via accept');
    like($r->{headers}{'content-type'} // '', qr/vnd\.daeha\.v1\+json/, 'v1 content-type');
}

# 기본은 v1
{
    my $d = _json(_full('/items'));
    ok(exists $d->{items}, 'default v1 shape');
}

done_testing();
