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
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('/api/ping')->{code}, '200', 'ping 200');

# 기본: page 1, per 10
{
    my $r = _full('/items');
    is($r->{code}, '200', '200');
    my $d = _json($r);
    is(scalar @{ $d->{data} }, 10, '10 items');
    is($d->{meta}{page}, 1, 'page 1');
    is($d->{meta}{total}, 57, 'total 57');
    is($d->{meta}{pages}, 6, '6 pages');
    is($d->{data}[0]{id}, 1, 'first id 1');
    like($r->{headers}{link} // '', qr/rel="next"/, 'has next');
    like($r->{headers}{link} // '', qr/rel="last"/, 'has last');
    unlike($r->{headers}{link} // '', qr/rel="prev"/, 'no prev on page 1');
}

# 마지막 페이지: 7개, prev/first/last
{
    my $r = _full('/items?page=6&per_page=10');
    my $d = _json($r);
    is(scalar @{ $d->{data} }, 7, 'last page 7 items');
    is($d->{data}[0]{id}, 51, 'starts at 51');
    like($r->{headers}{link} // '', qr/rel="prev"/, 'has prev');
    unlike($r->{headers}{link} // '', qr/rel="next"/, 'no next on last');
}

# 커스텀 per_page
{
    my $d = _json(_full('/items?page=2&per_page=5'));
    is(scalar @{ $d->{data} }, 5, 'per_page 5');
    is($d->{data}[0]{id}, 6, 'page2 per5 starts at 6');
}

# 범위를 벗어난 page 는 클램프
{
    my $d = _json(_full('/items?page=999'));
    is($d->{meta}{page}, 6, 'clamped to last page');
}

done_testing();
