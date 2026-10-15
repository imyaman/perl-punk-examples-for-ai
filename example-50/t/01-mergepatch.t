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
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', 'Content-Type: application/json' if defined $body;
    push @cmd, '--data-raw', $body if defined $body;
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

{
    my $d = _json(_full('GET', '/doc'));
    is($d->{title}, 'hello', 'initial title');
    is($d->{author}{name}, 'alice', 'initial author');
}

# merge: 스칼라 교체
{
    my $d = _json(_full('PATCH', '/doc', '{"title":"world"}'));
    is($d->{title}, 'world', 'title replaced');
    is($d->{author}{name}, 'alice', 'author preserved');
}

# merge: 중첩 객체의 null 은 삭제
{
    my $d = _json(_full('PATCH', '/doc', '{"author":{"name":null}}'));
    ok(!exists $d->{author}{name}, 'name removed');
    is($d->{author}{email}, 'a@example.com', 'email preserved');
}

# 배열은 통째로 교체 (객체가 아니므로)
{
    my $d = _json(_full('PATCH', '/doc', '{"tags":["x","y","z"]}'));
    is_deeply($d->{tags}, ['x','y','z'], 'array replaced');
}

# 객체를 null 로 삭제
{
    my $d = _json(_full('PATCH', '/doc', '{"author":null}'));
    ok(!exists $d->{author}, 'author removed');
}

# PUT 전체 교체
{
    my $d = _json(_full('PUT', '/doc', '{"fresh":1}'));
    is_deeply($d, { fresh => 1 }, 'put replaces whole doc');
}

done_testing();
