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

for my $code (301, 302, 303, 307, 308) {
    my $r = _full("/redirect/$code");
    is($r->{code}, "$code", "status $code");
    like($r->{headers}{location} // '', qr{/target$}, "Location -> /target ($code)");
}

{
    my $r = _full('/redirect/default');
    is($r->{code}, '302', 'default is 302');
    like($r->{headers}{location} // '', qr{/target$}, 'default Location');
}

{
    my $r = _full('/target');
    is($r->{code}, '200', 'target 200');
    like($r->{body}, qr/"at"\s*:\s*"target"/, 'target body');
}

done_testing();
