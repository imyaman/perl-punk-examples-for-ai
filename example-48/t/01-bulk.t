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

# ops 누락 400
is(_full('POST', '/bulk', '{}')->{code}, '400', 'missing ops 400');

# 정상 벌크: create 2개
{
    my $r = _full('POST', '/bulk', '{"ops":[{"op":"create","name":"a"},{"op":"create","name":"b"}]}');
    is($r->{code}, '200', 'all ok 200');
    my $d = _json($r);
    is($d->{ok}, 1, 'ok flag');
    is(scalar @{ $d->{results} }, 2, 'two results');
    is($d->{results}[0]{status}, 201, 'first created');
}

# store 확인
{
    my $d = _json(_full('GET', '/store'));
    is(scalar @{ $d->{items} }, 2, 'two items');
}

# 부분 실패: create + delete nonexistent -> 207
{
    my $r = _full('POST', '/bulk', '{"ops":[{"op":"create","name":"c"},{"op":"delete","id":999}]}');
    is($r->{code}, '207', 'partial 207');
    my $d = _json($r);
    is($d->{ok}, 0, 'ok false');
    is($d->{results}[1]{status}, 404, 'second 404');
}

# unknown op -> 207
{
    my $r = _full('POST', '/bulk', '{"ops":[{"op":"frobnicate"}]}');
    is($r->{code}, '207', 'unknown op 207');
}

done_testing();
