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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _index { my ($id, $t) = @_; return _json(_req('POST','/documents', JSON::PP->new->encode({ id => $id, text => $t }))) }
sub _search { return _json(_req('GET', "/search?q=$_[0]")) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 색인
{
    my $d = _index('d1', 'the quick brown fox');
    is($d->{id}, 'd1', 'indexed d1');
    is($d->{indexed_terms}, 4, 'four terms');
    is($d->{updated}, 0, 'new doc');
}
is(_index('d2', 'quick brown dog')->{id}, 'd2', 'indexed d2');
is(_index('d3', 'lazy dog')->{id}, 'd3', 'indexed d3');

# 단일 질의어
{
    my $d = _search('quick');
    is($d->{count}, 2, 'quick matches 2');
    my @ids = sort map { $_->{id} } @{ $d->{results} };
    is_deeply(\@ids, ['d1', 'd2'], 'quick -> d1,d2');
}

# AND 결합
is(_search('quick%20brown')->{count}, 2, 'quick brown -> 2');
is(_search('quick%20dog')->{count}, 1, 'quick dog -> 1 (AND)');
is(_search('quick%20fox')->{count}, 1, 'quick fox -> 1');
is(_search('quick%20fox')->{results}[0]{id}, 'd1', 'quick fox is d1');

# 대소문자 무시
is(_search('QUICK')->{count}, 2, 'case-insensitive');

# 없는 단어
is(_search('missing')->{count}, 0, 'no match');

# 랭킹 (tf 가중)
{
    _index('d4', 'fox fox fox');
    my $d = _search('fox');
    is($d->{count}, 2, 'fox matches d1,d4');
    is($d->{results}[0]{id}, 'd4', 'higher tf first');
    is($d->{results}[0]{score}, 3, 'score 3');
    is($d->{results}[1]{score}, 1, 'score 1');
}

# 문서 조회
is(_json(_req('GET','/documents/d1'))->{text}, 'the quick brown fox', 'doc text');

# 교체(색인 갱신)
{
    my $d = _index('d1', 'slow green turtle');
    is($d->{updated}, 1, 'replace marks updated');
    is(_search('quick')->{count}, 1, 'quick now only d2');
    is(_search('turtle')->{count}, 1, 'turtle -> d1');
    is(_search('fox')->{count}, 1, 'fox now only d4');
}

# 삭제
{
    is(_req('DELETE', '/documents/d3')->{code}, '204', 'delete 204');
    is(_req('GET', '/documents/d3')->{code}, '404', 'gone 404');
    is(_search('dog')->{count}, 1, 'dog -> d2 only');
}

# 통계
{
    my $d = _json(_req('GET', '/index/stats'));
    is($d->{documents}, 3, 'three docs');
    cmp_ok($d->{terms}, '>', 0, 'terms present');
}

# 오류
is(_req('GET','/search')->{code}, '400', 'no q 400');
is(_req('POST','/documents', '{}')->{code}, '400', 'no text 400');
is(_req('GET','/documents/nope')->{code}, '404', 'unknown doc 404');
is(_req('DELETE','/documents/nope')->{code}, '404', 'delete unknown 404');

done_testing();
