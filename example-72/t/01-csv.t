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

my $r = _get('/export.csv');
is($r->{code}, '200', 'csv 200');
like($r->{headers}{'content-type'} // '', qr{text/csv}, 'content-type');
like($r->{headers}{'content-disposition'} // '', qr/users\.csv/, 'disposition');

my @lines = split /\n/, $r->{body};
is($lines[0], 'id,name,email,note', 'header row');

like($r->{body}, qr{^1,Alice,alice\@example\.com,plain$}m, 'plain row');
like($r->{body}, qr/"Bob, Jr"/, 'comma field quoted');
like($r->{body}, qr/"has ""quotes"""/, 'quotes doubled');
like($r->{body}, qr/"multi\nline"/, 'newline quoted');

done_testing();
