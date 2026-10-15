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

is(_full('/api/ping')->{code}, '200', 'ping 200');

# 모든 필드
{
    my $d = _json(_full('/users/1'));
    is_deeply([ sort keys %{$d->{data}} ], [qw(age city email id name)], 'all fields');
}

# 부분 필드
{
    my $d = _json(_full('/users/1?fields=id,name'));
    is_deeply([ keys %{$d->{data}} ], [qw(id name)], 'only id,name');
    is($d->{data}{id}, 1, 'id present');
    is($d->{data}{age} // '', '', 'age absent');
}

# 순서가 바뀌어도 그대로
{
    my $d = _json(_full('/users/1?fields=name,id,age'));
    is($d->{data}{name}, 'alice', 'name ok');
    is($d->{data}{id}, 1, 'id ok');
    is($d->{data}{age}, 30, 'age ok');
    is($d->{data}{city} // '', '', 'city absent');
}

# 존재하지 않는 필드 -> 400
{
    my $r = _full('/users/1?fields=foo');
    is($r->{code}, '400', 'unknown field 400');
}

done_testing();
