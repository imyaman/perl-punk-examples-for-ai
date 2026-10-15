package Daeha;

use Punk;
use JSON::PP;

# ---- 세션 + CSRF 활성화 ----
session
    secret   => 'demo-session-secret-please-change',
    expires  => '1h',
    httponly => 1,
    samesite => 'Lax';

csrf
    field  => '_csrf',
    header => 'X-CSRF-Token',
    cookie => 'csrf';

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 토큰 발급 (안전한 GET) ----
get '/api/token' => sub {
    my ($c) = @_;
    $c->json({ csrf_token => $c->csrf_token });
};

# ---- 보호된 상태 변경 (POST) ----
post '/api/action' => sub {
    my ($c) = @_;
    $c->json({ ok => 1, did => 'action' });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 17: 일회용 CSRF 토큰)

=head1 SYNOPSIS

GET  /api/token   csrf_token 발급 (세션 쿠키 동반)
POST /api/action  X-CSRF-Token 헤더 필요 (사용 시 소비)
GET  /api/ping|healthz|readyz  헬스체크

=cut
