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

is(_full('/api/ping')->{code}, '200', 'ping 200');

{
    my $r = _full('/static/hello.txt');
    is($r->{code}, '200', 'txt 200');
    like($r->{body}, qr/Hello from a static file/, 'txt body');
    like($r->{headers}{'content-type'} // '', qr{^text/plain}, 'txt content-type');
}

{
    my $r = _full('/static/data.json');
    is($r->{code}, '200', 'json 200');
    like($r->{headers}{'content-type'} // '', qr{application/json}, 'json content-type');
    is(JSON::PP->new->decode($r->{body})->{name}, 'daeha', 'json parsed');
}

{
    my $r = _full('/static/index.html');
    is($r->{code}, '200', 'html 200');
    like($r->{headers}{'content-type'} // '', qr{text/html}, 'html content-type');
}

{
    is(_full('/static/missing.txt')->{code}, '404', 'missing file 404');
}

done_testing();
