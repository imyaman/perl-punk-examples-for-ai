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

sub _get { my ($path, $headers) = @_; return _req('GET', $path, undef, $headers // {}); }
sub _post { my ($path, $body, $headers) = @_; return _req('POST', $path, $body, $headers // {}); }

sub _decode { my ($res) = @_; my $raw = join("", @{$res->[2]}); return JSON::PP->new->decode($raw); }

# ---- 헬프 (기준선) ----
{
    my $res = _get('/api/ping');
    is($res->[0], 200, "GET /api/ping is 200");
    is(_decode($res)->{ping}, 'pong', "...ping pong");
}

# ---- 공개 엔드포인트 ----
{
    my $res = _get('/api/public');
    is($res->[0], 200, "GET /api/public is 200");
    my $d = _decode($res);
    is($d->{message}, '이 엔드포인트는 인증이 필요 없습니다', "...public message");
}

# ---- private: 키 없음 → 401 ----
{
    my $res = _get('/api/private');
    is($res->[0], 401, "GET /api/private no key is 401");
    is(_decode($res)->{error}{code}, 'API_KEY_MISSING', "...api key missing");
}

# ---- private: 잘못된 키 → 401 ----
{
    my $res = _req('GET', '/api/private', undef, { 'HTTP_X_API_KEY' => 'bad-key' });
    is($res->[0], 401, "GET /api/private bad key is 401");
}

# ---- private: 유효한 키 001 → 200 ----
{
    my $res = _req('GET', '/api/private', undef, { 'HTTP_X_API_KEY' => 'demo-key-001' });
    is($res->[0], 200, "GET /api/private with key-001 is 200");
    my $d = _decode($res);
    is($d->{api_key}{id}, 'key-001', "...key id");
    is($d->{api_key}{owner}, 'alice', "...owner");
    is_deeply($d->{api_key}{scopes}, ['read','write'], "...scopes");
}

# ---- private: 유효한 키 002 (읽기 전용) → 200 ----
{
    my $res = _req('GET', '/api/private', undef, { 'HTTP_X_API_KEY' => 'demo-key-002' });
    is($res->[0], 200, "GET /api/private with key-002 is 200");
    my $d = _decode($res);
    is($d->{api_key}{id}, 'key-002', "...key id");
    is_deeply($d->{api_key}{scopes}, ['read'], "...scopes read only");
}

# ---- 토큰 발급: 정상 → 200 + token ----
{
    my $res = _post('/api/token', '{"username":"alice","roles":["admin","user"]}');
    is($res->[0], 200, "POST /api/token is 200");
    my $d = _decode($res);
    isnt($d->{token}, undef, "...token present");
    like($d->{token}, qr/\./, "...token has segments");
    is($d->{token_type}, 'Bearer', "...token_type");
    is($d->{expires_in}, 3600, "...expires_in");
}

# ---- 토큰 발급: username 없음 → 400 ----
{
    my $res = _post('/api/token', '{"roles":["user"]}');
    is($res->[0], 400, "POST /api/token missing username is 400");
    is(_decode($res)->{error}{code}, 'MISSING_USERNAME', "...missing username");
}

# ---- 토큰 발급: body 없음 → 400 ----
{
    my $res = _post('/api/token', 'notjson');
    is($res->[0], 400, "POST /api/token bad json is 400");
    is(_decode($res)->{error}{code}, 'INVALID_JSON', "...invalid json");
}

# ---- admin: JWT (admin 역할) → 200 ----
my $admin_token = sub {
    my $res = _post('/api/token', '{"username":"admin-user","roles":["admin"]}');
    return _decode($res)->{token};
}->();

{
    my $res = _req('GET', '/api/admin', undef, { 'HTTP_AUTHORIZATION' => 'Bearer ' . $admin_token });
    is($res->[0], 200, "GET /api/admin with admin jwt is 200");
    my $d = _decode($res);
    is($d->{claims}{username}, 'admin-user', "...username in claims");
    is_deeply($d->{claims}{roles}, ['admin'], "...roles in claims");
}

# ---- admin: JWT role 없음 → 403 ----
my $user_token = sub {
    my $res = _post('/api/token', '{"username":"bob","roles":["user"]}');
    return _decode($res)->{token};
}->();

{
    my $res = _req('GET', '/api/admin', undef, { 'HTTP_AUTHORIZATION' => 'Bearer ' . $user_token });
    is($res->[0], 403, "GET /api/admin with non-admin jwt is 403");
    is(_decode($res)->{error}{code}, 'FORBIDDEN', "...forbidden");
}

# ---- admin: Authorization 없음 → 401 ----
{
    my $res = _get('/api/admin');
    is($res->[0], 401, "GET /api/admin no auth header is 401");
    is(_decode($res)->{error}{code}, 'UNAUTHORIZED', "...unauthorized");
}

# ---- admin: 잘못된 형식 → 400 ----
{
    my $res = _req('GET', '/api/admin', undef, { 'HTTP_AUTHORIZATION' => 'Basic abc' });
    is($res->[0], 400, "GET /api/admin bad auth format is 400");
    is(_decode($res)->{error}{code}, 'INVALID_AUTH_FORMAT', "...invalid auth format");
}

# ---- admin: 잘못된 토큰 → 401 ----
{
    my $res = _req('GET', '/api/admin', undef, { 'HTTP_AUTHORIZATION' => 'Bearer invalid.token.here' });
    is($res->[0], 401, "GET /api/admin invalid jwt is 401");
    is(_decode($res)->{error}{code}, 'INVALID_TOKEN', "...invalid token");
}

# ---- mixed: API 키만으로 접근 → 200 ----
{
    my $res = _req('GET', '/api/mixed', undef, { 'HTTP_X_API_KEY' => 'demo-key-001' });
    is($res->[0], 200, "GET /api/mixed with api key is 200");
    my $d = _decode($res);
    is($d->{auth}{type}, 'api_key', "...auth type api_key");
}

# ---- mixed: JWT만으로 접근 → 200 ----
{
    my $res = _req('GET', '/api/mixed', undef, { 'HTTP_AUTHORIZATION' => 'Bearer ' . $admin_token });
    is($res->[0], 200, "GET /api/mixed with jwt is 200");
    my $d = _decode($res);
    is($d->{auth}{type}, 'jwt', "...auth type jwt");
}

# ---- mixed: 둘 다 없음 → 401 ----
{
    my $res = _get('/api/mixed');
    is($res->[0], 401, "GET /api/mixed no credentials is 401");
}

done_testing();
