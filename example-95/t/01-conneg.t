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
sub _req {
    my ($path, $accept) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, ('-H', "Accept: $accept") if defined $accept;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my ($code, %h);
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}

is(_req('/api/ping')->{code}, '200', 'ping 200');

# JSON
{
    my $r = _req('/report', 'application/json');
    is($r->{code}, '200', 'json 200');
    like($r->{headers}{'content-type'}, qr{application/json}, 'json ct');
    my $d = JSON::PP->new->decode($r->{body});
    is($d->{count}, 3, 'json count');
    is($d->{rows}[1]{region}, 'US', 'json row');
}

# CSV
{
    my $r = _req('/report', 'text/csv');
    is($r->{code}, '200', 'csv 200');
    like($r->{headers}{'content-type'}, qr{text/csv}, 'csv ct');
    my @lines = split /\n/, $r->{body};
    is($lines[0], 'region,amount', 'csv header');
    is($lines[1], 'KR,100', 'csv row1');
    is(scalar @lines, 4, 'csv 4 lines');
}

# text
{
    my $r = _req('/report', 'text/plain');
    is($r->{code}, '200', 'text 200');
    like($r->{headers}{'content-type'}, qr{text/plain}, 'text content-type');
    like($r->{body}, qr/^KR: 100/m, 'text body');
}

# Accept 없으면 기본 json
{
    my $r = _req('/report');
    is($r->{code}, '200', 'default 200');
    like($r->{headers}{'content-type'}, qr{application/json}, 'default json');
}

# q 값으로 선택: xml(미지원) 무시하고 csv(q=0.5) 선택
{
    my $r = _req('/report', 'application/xml, text/csv;q=0.5');
    is($r->{code}, '200', 'q-values 200');
    like($r->{headers}{'content-type'}, qr{text/csv}, 'picked csv');
}

# 전부 미지원 -> 406
{
    my $r = _req('/report', 'application/xml');
    is($r->{code}, '406', 'unsupported 406');
    like($r->{headers}{'content-type'}, qr{problem\+json}, '406 problem+json');
}

done_testing();
