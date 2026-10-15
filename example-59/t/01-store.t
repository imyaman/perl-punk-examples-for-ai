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

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 초기화: 기존 노트 삭제
{
    my $d = _json(_req('GET', '/notes'));
    _req('DELETE', "/notes/$_->{id}") for @{ $d->{items} };
}

# 생성
my $id;
{
    my $r = _req('POST', '/notes', '{"text":"hello"}');
    is($r->{code}, '201', 'create 201');
    $id = _json($r)->{id};
    ok($id, 'got id');
}

# 조회
{
    my $r = _req('GET', "/notes/$id");
    is($r->{code}, '200', 'get 200');
    is(_json($r)->{text}, 'hello', 'text stored');
}

# 목록
{
    my $d = _json(_req('GET', '/notes'));
    my ($found) = grep { $_->{id} == $id } @{ $d->{items} };
    ok($found, 'in list');
}

# 텍스트 없음
is(_req('POST', '/notes', '{}')->{code}, '400', 'missing text 400');

# 삭제
is(_req('DELETE', "/notes/$id")->{code}, '204', 'delete 204');
is(_req('GET', "/notes/$id")->{code}, '404', 'gone 404');
is(_req('DELETE', "/notes/$id")->{code}, '404', 'delete missing 404');

# 영속성: 다시 만들고 목록에 남아있는지
{
    my $r = _req('POST', '/notes', '{"text":"persist"}');
    my $nid = _json($r)->{id};
    my $d = _json(_req('GET', '/notes'));
    my ($found) = grep { $_->{id} == $nid && $_->{text} eq 'persist' } @{ $d->{items} };
    ok($found, 'persisted to file');
    _req('DELETE', "/notes/$nid");
}

done_testing();
