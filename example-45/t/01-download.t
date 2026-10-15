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
    my $r = _full('/download/text');
    is($r->{code}, '200', 'text 200');
    like($r->{headers}{'content-type'} // '', qr{text/plain}, 'text/plain');
    like($r->{headers}{'content-disposition'} // '', qr/attachment.*hello\.txt/, 'attachment txt');
    like($r->{body}, qr/Hello from Punk/, 'text body');
}

{
    my $r = _full('/download/json');
    is($r->{code}, '200', 'json 200');
    like($r->{headers}{'content-disposition'} // '', qr/data\.json/, 'attachment json');
    like($r->{body}, qr/"items"/, 'json body');
}

{
    my $r = _full('/download/csv');
    is($r->{code}, '200', 'csv 200');
    like($r->{headers}{'content-type'} // '', qr{text/csv}, 'text/csv');
    like($r->{headers}{'content-disposition'} // '', qr/users\.csv/, 'attachment csv');
    like($r->{body}, qr/id,name/, 'csv body');
}

done_testing();
