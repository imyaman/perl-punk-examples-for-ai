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
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _ages { [ map { $_->{age} } @{ shift->{data} } ] }
sub _names { [ map { $_->{name} } @{ shift->{data} } ] }

is(_full('/api/ping')->{code}, '200', 'ping 200');

is_deeply(_ages(_json(_full('/users?sort=age'))), [25,25,30,36,41], 'age asc');
is_deeply(_ages(_json(_full('/users?sort=-age'))), [41,36,30,25,25], 'age desc');

# 다중 키: age 내림차순, 동률이면 name 오름차순
{
    my $d = _json(_full('/users?sort=-age,name'));
    is_deeply(_names($d), ['carol','alice','alice','bob','dave'], 'multi-key sort');
}

# 필터: name
{
    my $d = _json(_full('/users?name=alice'));
    is($d->{meta}{count}, 2, 'two alice');
}

# 필터: city
{
    my $d = _json(_full('/users?city=seoul'));
    is($d->{meta}{count}, 2, 'two in seoul');
}

# 범위 필터
{
    my $d = _json(_full('/users?min_age=30&max_age=36'));
    my @ages = sort { $a <=> $b } @{ _ages($d) };
    is_deeply(\@ages, [30,36], 'range 30..36');
}

# 결합
{
    my $d = _json(_full('/users?name=alice&sort=-age'));
    is_deeply(_ages($d), [36,30], 'alice sorted desc');
}

# 잘못된 정렬 필드 -> 400
{
    my $r = _full('/users?sort=nope');
    is($r->{code}, '400', 'bad sort field 400');
}

done_testing();
