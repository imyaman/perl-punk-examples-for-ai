#!/usr/bin/perl
use Test::More;

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

is(_full('/api/ping')->{code}, '200', 'ping 200');

{
    my $r = _full('/v1/legacy');
    is($r->{code}, '200', 'legacy 200');
    is($r->{headers}{deprecation}, 'true', 'Deprecation header');
    like($r->{headers}{sunset} // '', qr/GMT$/, 'Sunset is HTTP date');
    like($r->{headers}{link} // '', qr{rel="successor-version"}, 'Link successor');
    like($r->{headers}{link} // '', qr{/v2/modern}, 'points to v2');
    like($r->{headers}{warning} // '', qr/deprecated/i, 'Warning header');
}

{
    my $r = _full('/v2/modern');
    is($r->{code}, '200', 'modern 200');
    ok(!exists $r->{headers}{deprecation}, 'no deprecation');
}

done_testing();
