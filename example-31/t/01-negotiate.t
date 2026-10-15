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
    my ($path, %hdr) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    push @cmd, '-H', "$_: $hdr{$_}" for sort keys %hdr;
    my $out = _raw(@cmd);
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

# 기본 (curl 은 */* 를 보냄) -> JSON
{
    my $r = _full('/negotiate');
    is($r->{code}, '200', 'default 200');
    like($r->{headers}{'content-type'} // '', qr{application/json}, 'default json type');
    is(_json($r)->{format}, 'json', 'default json body');
}

# JSON 명시
{
    my $r = _full('/negotiate', Accept => 'application/json');
    is(_json($r)->{format}, 'json', 'json when asked');
}

# HTML 명시
{
    my $r = _full('/negotiate', Accept => 'text/html');
    is($r->{code}, '200', 'html 200');
    like($r->{headers}{'content-type'} // '', qr{text/html}, 'html type');
    like($r->{body}, qr{<li>alpha</li>}, 'html body');
}

# plain
{
    my $r = _full('/negotiate', Accept => 'text/plain');
    is($r->{code}, '200', 'plain 200');
    like($r->{headers}{'content-type'} // '', qr{text/plain}, 'plain type');
    like($r->{body}, qr{^alpha\n}, 'plain body');
}

# 지원되지 않는 타입 -> 406
{
    my $r = _full('/negotiate', Accept => 'application/xml');
    is($r->{code}, '406', 'unsupported 406');
}

done_testing();
