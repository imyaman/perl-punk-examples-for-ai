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
    my ($method, $path, %h) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    push @cmd, '-H', "x-api-key: $h{xapikey}" if exists $h{xapikey};
    my $out = _raw(@cmd);
    my ($head, $body) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($body // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

is(_full('GET', '/api/ping')->{code}, '200', 'ping 200');

# 공개
{
    my $r = _full('GET', '/api/public/info');
    is($r->{code}, '200', 'public 200');
    is(_json($r)->{public}, 1, 'public ok');
}

# 보호 - 키 없음
{
    my $r = _full('GET', '/api/protected/data');
    is($r->{code}, '403', 'no key 403');
}

# 보호 - 잘못된 키
{
    my $r = _full('GET', '/api/protected/data', xapikey => 'bad');
    is($r->{code}, '403', 'bad key 403');
}

# 보호 - 올바른 키(헤더)
{
    my $r = _full('GET', '/api/protected/data', xapikey => 'demo-key');
    is($r->{code}, '200', 'good key header 200');
    is(_json($r)->{data}[0]{name}, 'secret', 'data ok');
}

# 보호 - 올바른 키(쿼리)
{
    my $r = _full('GET', '/api/protected/data?api_key=demo-key');
    is($r->{code}, '200', 'good key query 200');
}

done_testing();
