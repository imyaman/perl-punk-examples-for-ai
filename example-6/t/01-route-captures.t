#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

sub _run {
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
    if ($@) { return { body => '', code => '000' }; }
    my ($body, $code) = $out =~ /^(.*)\n(\d{3})$/s;
    return { body => ($body // ''), code => ($code // '000') };
}

sub _get { my ($path) = @_; _run('curl', '-s', '--max-time', '18', '-w', '\n%{http_code}', "$BASE$path") }
sub _json { JSON::PP->new->decode(shift->{body}) }

# 헬스체크
{
    my $r = _get('/api/ping');
    is($r->{code}, '200', 'ping 200');
}

# ---- 단일 캡처 ----
{
    my $r = _get('/api/users/42');
    is($r->{code}, '200', 'users/42 200');
    is(_json($r)->{id}, '42', 'captured id');
}

# ---- 여러 캡처 ----
{
    my $r = _get('/api/pairs/foo/bar');
    is($r->{code}, '200', 'pairs 200');
    my $d = _json($r);
    is($d->{left},  'foo', 'left captured');
    is($d->{right}, 'bar', 'right captured');
}

# ---- 와일드카드: 나머지 전체 ----
{
    my $r = _get('/api/files/a/b/c.txt');
    is($r->{code}, '200', 'files 200');
    my $d = _json($r);
    is($d->{path}, 'a/b/c.txt', 'splat captures rest');
    is_deeply($d->{segments}, ['a','b','c.txt'], 'splat split into segments');
}

# ---- 슬래시 없는 단일 세그먼트 ----
{
    my $r = _get('/api/files/readme.md');
    is(_json($r)->{path}, 'readme.md', 'single-segment splat');
}

done_testing();
