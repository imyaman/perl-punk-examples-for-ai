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
sub _get {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
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

is(_get('/api/ping')->{code}, '200', 'ping 200');

{
    my $r = _get('/cache/public');
    is($r->{code}, '200', 'public 200');
    like($r->{headers}{'cache-control'} // '', qr/public/, 'public');
    like($r->{headers}{'cache-control'} // '', qr/max-age=3600/, 'max-age');
    like($r->{headers}{expires} // '', qr/GMT$/, 'expires set');
}

{
    my $r = _get('/cache/private');
    like($r->{headers}{'cache-control'} // '', qr/private/, 'private');
    like($r->{headers}{'cache-control'} // '', qr/no-store/, 'no-store');
    ok(!exists $r->{headers}{expires}, 'no expires for no-store');
}

{
    my $r = _get('/cache/no-cache');
    like($r->{headers}{'cache-control'} // '', qr/no-cache/, 'no-cache');
    like($r->{headers}{'cache-control'} // '', qr/must-revalidate/, 'must-revalidate');
}

{
    my $r = _get('/cache/swr');
    like($r->{headers}{'cache-control'} // '', qr/stale-while-revalidate=30/, 'swr');
}

{
    my $r = _get('/cache/immutable');
    like($r->{headers}{'cache-control'} // '', qr/immutable/, 'immutable');
    like($r->{headers}{'cache-control'} // '', qr/max-age=31536000/, 'long max-age');
}

is(_get('/cache/nope')->{code}, '404', 'unknown policy 404');

done_testing();
