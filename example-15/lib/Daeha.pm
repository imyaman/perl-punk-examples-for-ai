package Daeha;

use Punk;
use JSON::PP;

# ---- 플러그인 로드: 헬퍼 + before_dispatch 훅 설치 ----
plugin 'RequestId' => { prefix => 'rid' };

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 플러그인이 설치한 헬퍼 사용 ----
get '/api/whoami' => sub {
    my ($c) = @_;
    $c->json({ request_id => $c->request_id });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 15: plugin 으로 기능 묶어 재사용)

=head1 SYNOPSIS

GET /api/whoami    플러그인이 부여한 request id
GET /api/ping|healthz|readyz  헬스체크

플러그인 Punk::Plugin::RequestId 가 헬퍼 request_id 와
before_dispatch 훅을 설치합니다.

=cut
