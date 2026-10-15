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
sub _get {
    my ($path) = @_;
    my $out = _raw('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_get('/api/ping')->{code}, '200', 'ping 200');

# q 필수
is(_get('/search')->{code}, '400', 'no q 400');
is(_get('/search?q=')->{code}, '400', 'empty q 400');

# 이름/태그 검색
{
    my $d = _json(_get('/search?q=phone'));
    is($d->{count}, 3, 'three phones');
    # 이름에 phone 이 없고 태그만 -> 점수 1
    is($d->{items}[0]{score} >= 1 ? 1 : 0, 1, 'scores present');
}

# 대소문자 무시
{
    my $d = _json(_get('/search?q=APPLE'));
    is($d->{count}, 3, 'apple case-insensitive');
}

# 이름 매칭이 태그보다 높은 점수
{
    my $d = _json(_get('/search?q=watch'));
    is($d->{items}[0]{name}, 'Apple Watch', 'name match ranks first');
    cmp_ok($d->{items}[0]{score}, '>=', 2, 'name score >= 2');
}

# 결과 없음
{
    my $d = _json(_get('/search?q=zzz'));
    is($d->{count}, 0, 'no hits');
}

# 자동완성 prefix
{
    my $d = _json(_get('/search/suggest?prefix=ap'));
    is_deeply($d->{suggestions}, ['Apple iPhone', 'Apple Watch', 'Apple Pencil'], 'prefix suggestions');
}

# 자동완성 limit
{
    my $d = _json(_get('/search/suggest?prefix=a&limit=2'));
    is(scalar @{ $d->{suggestions} }, 2, 'limit honored');
}

is(_get('/search/suggest')->{code}, '400', 'suggest no prefix 400');

done_testing();
