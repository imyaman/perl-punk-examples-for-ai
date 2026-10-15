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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', 'Content-Type: application/json' if defined $body;
    push @cmd, '--data-raw', $body if defined $body;
    my $out = _raw(@cmd);
    my ($head, $body2) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    my %h;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($body2 // '') };
}

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# JSONP
{
    my $r = _full('GET', '/items?callback=foo');
    is($r->{code}, '200', 'jsonp 200');
    like($r->{headers}{'content-type'} // '', qr/application\/javascript/, 'js content-type');
    like($r->{body}, qr/^foo\(/, 'starts foo(');
    like($r->{body}, qr/\);$/, 'ends );');
}

# JSONP with dots/dollar
{
    my $r = _full('GET', '/items?callback=jQuery123._0');
    like($r->{body}, qr/^jQuery123\._0\(/, 'valid callback chars');
}

# invalid callback → 400
{
    my $r = _full('GET', '/items?callback=foo<bar>');
    is($r->{code}, '400', 'invalid callback 400');
}

done_testing();
