package Daeha;

use Punk;
use JSON::PP;

# ---- API 키 스토어 (예제용) ----
my %API_KEYS = (
    'demo-key-001' => { id => 'key-001', owner => 'alice', scopes => ['read','write'] },
    'demo-key-002' => { id => 'key-002', owner => 'bob',   scopes => ['read'] },
);

my $JWT_SECRET = 'super-secret-demo-only';

sub _now_epoch { time() }

sub _make_jwt {
    my ($payload) = @_;
    my $header = JSON::PP->new->encode({ alg => 'HS256', typ => 'JWT' });
    my $claims = JSON::PP->new->encode($payload);
    my $sig = _mock_sign($header, $claims);
    return join('.', $header, $claims, $sig);
}

sub _mock_sign {
    my ($h, $c) = @_;
    require Digest::SHA;
    my $raw = $h . '.' . $c . '.' . $JWT_SECRET;
    return Digest::SHA::sha256_hex($raw);
}

sub _b64url_decode {
    my ($b64) = @_;
    require MIME::Base64;
    $b64 =~ s/-/+/g;
    $b64 =~ s/_/\//g;
    return MIME::Base64::decode($b64);
}

sub _verify_jwt {
    my ($token) = @_;
    return undef unless defined $token && $token =~ /^([^.]+)\.([^.]+)\.([^.]+)$/;
    my ($header_json, $claims_json, $sig_given) = ($1, $2, $3);
    my $expected = _mock_sign($header_json, $claims_json);
    return undef unless $sig_given eq $expected;
    my $claims = eval { JSON::PP->new->decode($claims_json) } || undef;
    return $claims;
}

sub _authenticate_jwt {
    my ($c) = @_;
    my $auth = $c->req->header('authorization') // '';
    if ($auth eq '') {
        return $c->json({
            error => { code => 'UNAUTHORIZED', message => 'Authorization: Bearer <token>이 필요합니다' },
        }, 401);
    }
    unless ($auth =~ /^Bearer\s+(.+)$/) {
        return $c->json({
            error => { code => 'INVALID_AUTH_FORMAT', message => 'Authorization 헤더 형식이 잘못되었습니다' },
        }, 400);
    }
    my $token = $1;
    my $claims = _verify_jwt($token);
    unless ($claims) {
        return $c->json({
            error => { code => 'INVALID_TOKEN', message => '토큰이 유효하지 않습니다' },
        }, 401);
    }
    return $claims;
}

# ---- 헬프 (기준선 유지) ----
get '/api/ping' => sub {
    my ($c) = @_;
    $c->json({ ping => 'pong' });
};

get '/api/healthz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ok' });
};

get '/api/readyz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ready' });
};

# ---- 공개 엔드포인트 ----
get '/api/public' => sub {
    my ($c) = @_;
    $c->json({ message => '이 엔드포인트는 인증이 필요 없습니다' });
};

# ---- API 키 인증 ----
get '/api/private' => sub {
    my ($c) = @_;
    my $key = $c->req->header('x-api-key') // '';
    my $info = $API_KEYS{$key};
    unless ($info) {
        return $c->json({
            error => { code => 'API_KEY_MISSING', message => '유효한 X-API-Key 헤더가 필요합니다' },
        }, 401);
    }
    $c->stash->{auth} = { type => 'api_key', info => $info };
    $c->json({
        message => 'API 키로 인증되었습니다',
        api_key => { id => $info->{id}, owner => $info->{owner}, scopes => $info->{scopes} },
    });
};

# ---- JWT 인증 + 관리자 역할 요구 ----
get '/api/admin' => sub {
    my ($c) = @_;
    my $claims = _authenticate_jwt($c);
    return $claims if ref $claims eq 'ARRAY';   # 인증 실패 응답이면 그대로 반환
    my $roles = $claims->{roles} // [];
    my $is_admin = 0;
    for my $r (@$roles) {
        if ($r eq 'admin') { $is_admin = 1; last; }
    }
    unless ($is_admin) {
        return $c->json({
            error => { code => 'FORBIDDEN', message => '이 작업에는 admin 역할이 필요합니다' },
        }, 403);
    }
    $c->stash->{auth} = { type => 'jwt', claims => $claims };
    $c->json({
        message => 'JWT로 관리자 인증되었습니다',
        claims => $claims,
    });
};

# ---- 혼합 인증: API 키 또는 JWT ----
get '/api/mixed' => sub {
    my ($c) = @_;
    my $key = $c->req->header('x-api-key') // '';
    if (my $info = $API_KEYS{$key}) {
        $c->stash->{auth} = { type => 'api_key', info => $info };
        return $c->json({
            message => '인증되었습니다 (혼합)',
            auth => { type => 'api_key', info => $info },
        });
    }
    my $claims = _authenticate_jwt($c);
    if (ref $claims eq 'ARRAY') {
        return $claims;   # JWT 인증 실패 응답 반환
    }
    $c->stash->{auth} = { type => 'jwt', claims => $claims };
    return $c->json({
        message => '인증되었습니다 (혼합)',
        auth => { type => 'jwt', claims => $claims },
    });
};

# ---- JWT 발급 데모 ----
post '/api/token' => sub {
    my ($c) = @_;
    my $input = eval { $c->req->json };
    if ($@ || !defined $input || ref $input ne 'HASH') {
        return $c->json({
            error => { code => 'INVALID_JSON', message => 'request body must be a JSON object' },
        }, 400);
    }
    my $username = $input->{username};
    my $roles = $input->{roles} // ['user'];
    if (!defined $username || $username eq '') {
        return $c->json({
            error => { code => 'MISSING_USERNAME', message => 'username이 필요합니다' },
        }, 400);
    }
    my $token = _make_jwt({
        sub   => 'demo-service',
        iss   => 'demo-auth',
        aud   => 'demo-api',
        iat   => _now_epoch(),
        exp   => _now_epoch() + 3600,
        username => $username,
        roles  => $roles,
    });
    $c->json({
        token => $token,
        token_type => 'Bearer',
        expires_in => 3600,
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 4: 인증 — API 키 + JWT)

=head1 SYNOPSIS

GET  /api/public                  인증 불필요
GET  /api/private                 API 키 필요 (X-API-Key: demo-key-001)
GET  /api/admin                   JWT 필요 + role=admin
GET  /api/mixed                   API 키 또는 JWT
POST /api/token                   JWT 발급 데모 (username 전달)

유효 키:
- demo-key-001 (alice, read+write)
- demo-key-002 (bob, read)

JWT 검증은 예제용 모의 서명(Digest::SHA 기반)이며, 실제 JWT 라이브러리가 아닙니다.

=cut
