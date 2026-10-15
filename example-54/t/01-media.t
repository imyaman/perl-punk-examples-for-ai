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
sub _post {
    my ($ct, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', 'POST', "$BASE/echo");
    push @cmd, '-H', "Content-Type: $ct" if defined $ct;
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

is(_raw('curl','-s','-o','/dev/null','-w','%{http_code}',"$BASE/api/ping") eq '200' ? 1 : 0, 1, 'ping');

# 정상
{
    my $r = _post('application/json', '{"a":1}');
    is($r->{code}, '200', 'json 200');
    is(_json($r)->{received}{a}, 1, 'echoed');
}

# charset 파라미터 허용
{
    my $r = _post('application/json; charset=utf-8', '{"b":2}');
    is($r->{code}, '200', 'json+charset 200');
}

# text/plain -> 415
{
    my $r = _post('text/plain', 'hello');
    is($r->{code}, '415', 'text/plain 415');
}

# 없음 -> 415
{
    my $r = _post(undef, 'hello');
    is($r->{code}, '415', 'missing ct 415');
}

# 깨진 JSON -> 400
{
    my $r = _post('application/json', '{bad json');
    is($r->{code}, '400', 'malformed 400');
}

done_testing();
