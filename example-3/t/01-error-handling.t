#!/usr/bin/perl
use Test::More;
use JSON::PP;
use File::Temp qw(tempfile);

use_ok('Daeha');

my $app = Daeha->to_app;
ok($app, "the application compiles to a PSGI coderef");

sub _req {
    my ($method, $path, $body, $headers) = @_;
    $headers //= {};
    my $env = {
        REQUEST_METHOD => $method,
        PATH_INFO      => $path,
        SERVER_NAME    => 'localhost',
        %$headers,
    };
    if ($body) {
        my ($fh, $filename) = tempfile();
        print $fh $body;
        close $fh;
        open my $in, '<', $filename or die "open tempfile: $!";
        $env->{'psgi.input'} = $in;
        $env->{CONTENT_LENGTH} = length($body);
        $env->{CONTENT_TYPE}   = 'application/json';
    }
    my $res = $app->($env);
    if ($env->{'psgi.input'}) {
        close $env->{'psgi.input'};
        unlink $filename;
    }
    return $res;
}

sub _get {
    my ($path, $query) = @_;
    my $qs = $query // '';
    return _req('GET', $path, undef, { QUERY_STRING => $qs });
}

sub _post {
    my ($path, $body) = @_;
    return _req('POST', $path, $body);
}

sub _decode {
    my ($res) = @_;
    my $raw = join("", @{$res->[2]});
    return JSON::PP->new->decode($raw);
}

sub _headers {
    my ($res) = @_;
    return { map { $_->[0] => $_->[1] } @{$res->[1]} };
}

# ---- 헬프 (기준선) ----
{
    my $res = _get('/api/ping');
    is($res->[0], 200, "GET /api/ping is 200");
    is(_decode($res)->{ping}, 'pong', "...ping pong");
}

# ---- echo 기본 (200) ----
{
    my $res = _get('/api/echo', 'x=1');
    is($res->[0], 200, "GET /api/echo is 200");
    my $d = _decode($res);
    is($d->{method}, 'GET', "...method");
    is($d->{path}, '/api/echo', "...path");
    isnt($d->{query}, undef, "...query present");
}

# ---- echo ?code=404 → 404 + echoed_status ----
{
    my $res = _get('/api/echo', 'code=404');
    is($res->[0], 404, "GET /api/echo?code=404 is 404");
    my $d = _decode($res);
    is($d->{error}{code}, 'ECHO_STATUS', "...error code");
    is($d->{echoed_status}, 404, "...echoed_status 404");
}

# ---- echo ?code=201 → 201 ----
{
    my $res = _get('/api/echo', 'code=201');
    is($res->[0], 201, "GET /api/echo?code=201 is 201");
    my $d = _decode($res);
    is($d->{echoed_status}, 201, "...echoed_status 201");
}

# ---- echo ?code=99 → 400 (범위 밖) ----
{
    my $res = _get('/api/echo', 'code=99');
    is($res->[0], 400, "GET /api/echo?code=99 is 400");
    my $d = _decode($res);
    is($d->{error}{code}, 'INVALID_STATUS', "...invalid status code");
}

# ---- echo ?code=9999 → 400 ----
{
    my $res = _get('/api/echo', 'code=9999');
    is($res->[0], 400, "GET /api/echo?code=9999 is 400");
    my $d = _decode($res);
    is($d->{error}{code}, 'INVALID_STATUS', "...invalid status code");
}

# ---- validate 정상 ----
{
    my $res = _post('/api/validate', '{"email":"a@b.com","age":20,"role":"user"}');
    is($res->[0], 200, "POST /api/validate valid is 200");
    my $d = _decode($res);
    is($d->{valid}, JSON::PP::true, "...valid true");
    isnt($d->{processed_at}, undef, "...processed_at present");
}

# ---- validate 이메일 누락 → 422 ----
{
    my $res = _post('/api/validate', '{"age":20,"role":"user"}');
    is($res->[0], 422, "POST /api/validate missing email is 422");
    my $d = _decode($res);
    is($d->{error}{code}, 'VALIDATION_ERROR', "...validation error code");
    my @fields = map { $_->{field} } @{ $d->{error}{details} };
    is_deeply(\@fields, ['email'], "...email field error");
}

# ---- validate age 음수 → 422 ----
{
    my $res = _post('/api/validate', '{"email":"a@b.com","age":-1}');
    is($res->[0], 422, "POST /api/validate negative age is 422");
    my $d = _decode($res);
    my @fields = map { $_->{field} } @{ $d->{error}{details} };
    ok(grep { $_ eq 'age' } @fields, "...age field error");
}

# ---- validate role 잘못된 값 → 422 ----
{
    my $res = _post('/api/validate', '{"email":"a@b.com","role":"superuser"}');
    is($res->[0], 422, "POST /api/validate bad role is 422");
    my $d = _decode($res);
    my @fields = map { $_->{field} } @{ $d->{error}{details} };
    ok(grep { $_ eq 'role' } @fields, "...role field error");
}

# ---- validate body 없음 → 400 ----
{
    my $res = _post('/api/validate', 'notjson');
    is($res->[0], 400, "POST /api/validate bad json is 400");
    my $d = _decode($res);
    is($d->{error}{code}, 'INVALID_JSON', "...invalid json");
}

# ---- register 정상 → 201 ----
{
    my $res = _post('/api/register', '{"id":"u1","name":"Alice"}');
    is($res->[0], 201, "POST /api/register is 201");
    my $d = _decode($res);
    is($d->{registered}{id}, 'u1', "...id");
    is($d->{registered}{name}, 'Alice', "...name");
    isnt($d->{registered}{created_at}, undef, "...created_at");
}

# ---- register 중복 id → 409 ----
{
    my $res = _post('/api/register', '{"id":"u1","name":"Bob"}');
    is($res->[0], 409, "POST /api/register duplicate is 409");
    my $d = _decode($res);
    is($d->{error}{code}, 'USER_EXISTS', "...user exists code");
    is($d->{error}{details}{existing_id}, 'u1', "...existing id");
}

# ---- register id/name 누락 → 400 ----
{
    my $res = _post('/api/register', '{"id":"u2"}');
    is($res->[0], 400, "POST /api/register missing name is 400");
    my $d = _decode($res);
    is($d->{error}{code}, 'MISSING_FIELDS', "...missing fields");
}

# ---- secret: 헤더 없음 → 401 ----
{
    my $res = _get('/api/secret');
    is($res->[0], 401, "GET /api/secret no auth header is 401");
    my $d = _decode($res);
    is($d->{error}{code}, 'UNAUTHORIZED', "...unauthorized");
}

# ---- secret: Bearer 아닌 포맷 → 400 ----
{
    my $res = _req('GET', '/api/secret', undef, { 'HTTP_AUTHORIZATION' => 'Basic abc' });
    is($res->[0], 400, "GET /api/secret bad auth format is 400");
    my $d = _decode($res);
    is($d->{error}{code}, 'INVALID_AUTH_FORMAT', "...invalid auth format");
}

# ---- secret: 토큰 OK → 200 ----
{
    my $res = _req('GET', '/api/secret', undef, { 'HTTP_AUTHORIZATION' => 'Bearer OK' });
    is($res->[0], 200, "GET /api/secret valid token is 200");
    my $d = _decode($res);
    is($d->{secret}, 'here is the secret data', "...secret returned");
}

# ---- secret: 토큰 DENY → 403 ----
{
    my $res = _req('GET', '/api/secret', undef, { 'HTTP_AUTHORIZATION' => 'Bearer DENY' });
    is($res->[0], 403, "GET /api/secret deny token is 403");
    my $d = _decode($res);
    is($d->{error}{code}, 'FORBIDDEN', "...forbidden");
}

# ---- secret: 모르는 토큰 → 401 ----
{
    my $res = _req('GET', '/api/secret', undef, { 'HTTP_AUTHORIZATION' => 'Bearer UNKNOWN' });
    is($res->[0], 401, "GET /api/secret unknown token is 401");
    my $d = _decode($res);
    is($d->{error}{code}, 'INVALID_TOKEN', "...invalid token");
}

# ---- rate-limited-demo: 1~3 허용, 4번째 429 ----
{
    # 각 요청은 새 env 이지만 인메모리 카운터는 앱 레벨이므로 누적됨
    my $ok = 0;
    for my $i (1..3) {
        my $res = _get('/api/rate-limited-demo', '', { 'HTTP_X_DEMO_CLIENT' => 'test-client' });
        my $d = _decode($res);
        is($res->[0], 200, "rate-limited request $i is 200");
        is($d->{allowed}, JSON::PP::true, "...allowed");
        is($d->{request_number}, $i, "...request number $i");
        $ok++;
    }
    my $res = _get('/api/rate-limited-demo', '', { 'HTTP_X_DEMO_CLIENT' => 'test-client' });
    my $d = _decode($res);
    is($res->[0], 429, "...4th request is 429");
    is($d->{error}{code}, 'TOO_MANY_REQUESTS', "...too many requests code");
    is($d->{retry_after_sec}, 5, "...retry_after 5");
}

# ---- simulate-error?mode=500 → 500 ----
{
    my $res = _get('/api/simulate-error', 'mode=500');
    is($res->[0], 500, "GET /api/simulate-error?mode=500 is 500");
}

# ---- simulate-error 기본값 → 200 ----
{
    my $res = _get('/api/simulate-error', 'mode=none');
    is($res->[0], 200, "GET /api/simulate-error?mode=none is 200");
    my $d = _decode($res);
    is($d->{mode}, 'none', "...mode none");
}

done_testing();
