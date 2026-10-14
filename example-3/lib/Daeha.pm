package Daeha;

use Punk;
use JSON::PP;

# ---- 인메모리 사용자 저장소 (409 데모용) ----
my %USERS = ();
my %RATE_LIMITS = ();

sub _now_iso {
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time());
    $mon += 1;
    $year += 1900;
    return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year, $mon, $mday, $hour, $min, $sec);
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

# ---- 상태코드 에코 (데모용) ----
get '/api/echo' => sub {
    my ($c) = @_;
    my $code = $c->req->query->{code} // '';
    if (defined $code && $code =~ /^\d+$/) {
        my $status = $code + 0;
        if ($status < 100 || $status >= 600) {
            return $c->json({
                error => { code => 'INVALID_STATUS', message => 'status code must be 100-599' },
            }, 400);
        }
        return $c->json({
            error => { code => 'ECHO_STATUS', message => "echoing status $status" },
            echoed_status => $status,
        }, $status);
    }
    $c->json({
        method     => $c->req->method,
        path       => $c->req->path,
        query      => ($c->req->query // {}),
        headers    => _safe_headers($c),
    });
};

sub _safe_headers {
    my ($c) = @_;
    my $h = $c->req->headers;
    my %out;
    for my $k (keys %$h) {
        my $v = $h->{$k};
        $out{$k} = ref $v eq 'ARRAY' ? $v : $v;
    }
    return \%out;
}

# ---- 입력 검증 (422 데모) ----
post '/api/validate' => sub {
    my ($c) = @_;
    my $input = eval { $c->req->json };
    if ($@ || !defined $input || ref $input ne 'HASH') {
        return $c->json({
            error => { code => 'INVALID_JSON', message => 'request body must be a JSON object' },
        }, 400);
    }
    my @errors;
    push @errors, { field => 'email', message => 'email is required' }
        unless $input->{email} && $input->{email} =~ /.+@.+/;
    push @errors, { field => 'age', message => 'age must be a positive integer' }
        if defined $input->{age} && ( $input->{age} !~ /^\d+$/ || $input->{age} + 0 < 1 );
    push @errors, { field => 'role', message => 'role must be one of admin, user, viewer' }
        if defined $input->{role} && $input->{role} !~ /^(admin|user|viewer)$/;

    if (@errors) {
        return $c->json({
            error => {
                code => 'VALIDATION_ERROR',
                message => 'input validation failed',
                details => \@errors,
            },
        }, 422);
    }

    $c->json({
        valid => JSON::PP::true,
        processed_at => _now_iso(),
    });
};

# ---- 사용자 등록 (409 Conflict 데모) ----
post '/api/register' => sub {
    my ($c) = @_;
    my $input = eval { $c->req->json };
    if ($@ || !defined $input || ref $input ne 'HASH') {
        return $c->json({
            error => { code => 'INVALID_JSON', message => 'request body must be a JSON object' },
        }, 400);
    }
    my $id = $input->{id};
    my $name = $input->{name};
    unless (defined $id && defined $name) {
        return $c->json({
            error => { code => 'MISSING_FIELDS', message => 'id and name are required' },
        }, 400);
    }
    if (exists $USERS{$id}) {
        return $c->json({
            error => {
                code => 'USER_EXISTS',
                message => 'a user with this id already exists',
                details => { existing_id => $id },
            },
        }, 409);
    }
    $USERS{$id} = {
        id    => $id,
        name  => $name,
        created_at => _now_iso(),
    };
    $c->json({ registered => $USERS{$id} }, 201);
};

# ---- 인증 데모 (401/400/403) ----
get '/api/secret' => sub {
    my ($c) = @_;
    my $auth = $c->req->header('authorization') // '';
    if ($auth eq '') {
        return $c->json({
            error => { code => 'UNAUTHORIZED', message => 'authorization header is required' },
        }, 401);
    }
    if ($auth !~ /^Bearer\s+.+/) {
        return $c->json({
            error => { code => 'INVALID_AUTH_FORMAT', message => 'authorization must be Bearer <token>' },
        }, 400);
    }
    my $token = $auth;
    $token =~ s/^Bearer\s+//;
    if ($token eq 'DENY') {
        return $c->json({
            error => { code => 'FORBIDDEN', message => 'insufficient permissions' },
        }, 403);
    }
    if ($token eq 'OK') {
        return $c->json({ secret => 'here is the secret data', token_used => $token });
    }
    return $c->json({
        error => { code => 'INVALID_TOKEN', message => 'token is not recognized' },
    }, 401);
};

# ---- 속도 제한 데모 (429) ----
get '/api/rate-limited-demo' => sub {
    my ($c) = @_;
    my $key = $c->req->header('x-demo-client') // 'anonymous';
    my $count = ++$RATE_LIMITS{$key} || 1;
    if ($count > 3) {
        return $c->json({
            error => {
                code => 'TOO_MANY_REQUESTS',
                message => 'rate limit exceeded for this demo client',
                details => { limit => 3, current => $count },
            },
            retry_after_sec => 5,
        }, 429);
    }
    $c->json({
        allowed => JSON::PP::true,
        request_number => $count,
        remaining => 3 - $count,
    });
};

# ---- 의도적 500 시뮬레이션 (에러 핸들러 demo용) ----
get '/api/simulate-error' => sub {
    my ($c) = @_;
    my $mode = $c->req->query->{mode} // '';
    if ($mode eq '500') {
        die "simulated internal error for demonstration\n";
    }
    $c->json({ mode => $mode, message => 'no error simulated' });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 3: 에러 처리 & 상태코드)

=head1 SYNOPSIS

GET  /api/echo                      요청 에코 / ?code=404 → 해당 상태코드 + 에러
POST /api/validate                  입력 검증 (422 + 상세)
POST /api/register                  사용자 등록 (409 중복)
GET  /api/secret                    인증 데모 (401/400/403)
GET  /api/rate-limited-demo         속도 제한 데모 (429)
GET  /api/simulate-error?mode=500  의도적 500 시뮬레이션
GET  /api/ping|healthz|readyz      헬스체크

=cut
