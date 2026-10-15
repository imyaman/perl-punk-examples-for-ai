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

my $id;
{
    my $r = _req('POST', '/items', '{"name":"keep"}');
    is($r->{code}, '201', 'create 201');
    $id = _json($r)->{id};
    is(_json($r)->{deleted}, 0, 'not deleted');
}

# 소프트 삭제
is(_req('DELETE', "/items/$id")->{code}, '204', 'delete 204');

# 기본 조회 404
is(_req('GET', "/items/$id")->{code}, '404', 'hidden 404');
# include_deleted 로 조회 가능
{
    my $r = _req('GET', "/items/$id?include_deleted=1");
    is($r->{code}, '200', 'include_deleted 200');
    is(_json($r)->{deleted}, 1, 'deleted flag');
}

# 목록에서 제외 / include_deleted 포함 / only_deleted
{
    my $def = _json(_req('GET', '/items'));
    my ($found) = grep { $_->{id} == $id } @{ $def->{items} };
    ok(!$found, 'not in default list');

    my $inc = _json(_req('GET', '/items?include_deleted=1'));
    ($found) = grep { $_->{id} == $id } @{ $inc->{items} };
    ok($found && $found->{deleted}, 'in include_deleted list');

    my $only = _json(_req('GET', '/items?only_deleted=1'));
    ($found) = grep { $_->{id} == $id } @{ $only->{items} };
    ok($found, 'in only_deleted list');
}

# 복구
{
    my $r = _req('POST', "/items/$id/restore");
    is($r->{code}, '200', 'restore 200');
    is(_json($r)->{deleted}, 0, 'restored');
    is(_req('GET', "/items/$id")->{code}, '200', 'visible again');
}

# 이미 복구됨 -> 409
is(_req('POST', "/items/$id/restore")->{code}, '409', 'restore again 409');

# 없는 항목 삭제/복구
is(_req('DELETE', '/items/99999')->{code}, '404', 'delete missing 404');
is(_req('POST', '/items/99999/restore')->{code}, '404', 'restore missing 404');

done_testing();
