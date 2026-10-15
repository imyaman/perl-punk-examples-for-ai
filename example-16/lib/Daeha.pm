package Daeha;

use Punk;
use JSON::PP;

# ---- 서명 쿠키 세션 활성화 ----
session
    secret   => 'demo-session-secret-please-change',
    expires  => '7d',
    httponly => 1,
    samesite => 'Lax';

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 로그인: 세션에 사용자 기록 ----
post '/api/login' => sub {
    my ($c) = @_;
    my $user = $c->param('user') // '';
    return $c->json({ error => 'user required' }, 400) unless length $user;
    $c->session->{user} = $user;
    $c->json({ ok => 1, user => $user, logged_in => 1 });
};

# ---- 세션 조회 ----
get '/api/me' => sub {
    my ($c) = @_;
    my $u = $c->session->{user};
    return $c->json({ error => 'not logged in' }, 401) unless $u;
    $c->json({ user => $u });
};

# ---- 로그아웃: 세션 만료 ----
post '/api/logout' => sub {
    my ($c) = @_;
    $c->session_expire;
    $c->json({ ok => 1, logged_out => 1 });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 16: 서명 쿠키 세션)

=head1 SYNOPSIS

POST /api/login   폼 user=<name> -> 세션 기록
GET  /api/me      세션의 사용자 조회
POST /api/logout  세션 만료
GET  /api/ping|healthz|readyz  헬스체크

=cut
