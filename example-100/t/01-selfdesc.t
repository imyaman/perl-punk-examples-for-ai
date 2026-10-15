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
    my ($path) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', "$BASE$path");
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my ($code, %h);
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; next }
        next unless $line =~ /^([^:]+):\s*(.*?)\s*$/;
        $h{lc $1} = $2;
    }
    return { code => $code, headers => \%h, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }

# 루트 서술
{
    my $r = _req('/');
    is($r->{code}, '200', 'root 200');
    like($r->{headers}{'content-type'}, qr{application/json}, 'json content-type');
    my $d = _json($r);
    is($d->{service}, 'daeha-api', 'service name');
    is($d->{version}, '1.0.0', 'version');
    is($d->{api_version}, 'v1', 'api version');
    is($d->{status}, 'ok', 'status');
    ok(ref $d->{endpoints} eq 'ARRAY' && @{ $d->{endpoints} } >= 4, 'endpoints listed');
    is($d->{documentation}, '/openapi.json', 'docs link');
    is($d->{links}{health}, '/api/healthz', 'health link');
}

# 엔드포인트 목록이 실제 라우트를 가리킨다
{
    my $d = _json(_req('/'));
    my %paths = map { $_->{path} => 1 } @{ $d->{endpoints} };
    ok($paths{'/api/ping'}, 'lists /api/ping');
    ok($paths{'/_smoke'},  'lists /_smoke');
}

# OpenAPI 명세
{
    my $r = _req('/openapi.json');
    is($r->{code}, '200', 'openapi 200');
    my $d = _json($r);
    like($d->{openapi}, qr/^3\./, 'openapi 3.x');
    is($d->{info}{title}, 'daeha-api', 'spec title');
    is($d->{info}{version}, '1.0.0', 'spec version');
    ok($d->{paths}{'/api/ping'}, 'spec has /api/ping');
    ok($d->{paths}{'/api/ping'}{get}, 'GET /api/ping defined');
    ok($d->{paths}{'/_smoke'}, 'spec has /_smoke');
}

# 스모크
{
    my $r = _req('/_smoke');
    is($r->{code}, '200', 'smoke 200');
    is($r->{headers}{'x-smoke'}, 'pass', 'smoke pass header');
    my $d = _json($r);
    ok($d->{ok}, 'all checks ok');
    ok(@{ $d->{checks} } >= 2, 'checks listed');
    is($d->{checks}[0]{name}, 'json_encode', 'first check name');
}

# 기본 헬스
{
    is(_req('/api/ping')->{code}, '200', 'ping 200');
    my $h = _json(_req('/api/healthz'));
    is($h->{status}, 'ok', 'healthz ok');
    ok(defined $h->{uptime}, 'uptime present');
    is(_req('/api/readyz')->{code}, '200', 'readyz 200');
}

# 미정의 경로
is(_req('/nope')->{code}, '404', 'unknown 404');

done_testing();
