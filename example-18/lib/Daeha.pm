package Daeha;

use Punk;
use JSON::PP;

# ---- CORS: 특정 오리진만, 자격증명 허용, /api 하위에만 ----
cors
    origins     => ['https://app.example.com'],
    credentials => 1,
    headers     => [ qw(Content-Type X-CSRF-Token) ],
    expose      => [qw(X-Request-Id)],
    max_age     => 600,
    paths       => ['/api'];

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- CORS 대상 엔드포인트 ----
get '/api/data' => sub {
    my ($c) = @_;
    $c->json({ data => [ 1, 2, 3 ] });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 18: CORS)

=head1 SYNOPSIS

GET     /api/data   CORS 오리진 검사
OPTIONS /api/data   프리플라이트 자동 응답
GET     /api/ping|healthz|readyz  헬스체크

허용 오리진: https://app.example.com (자격증명 허용)

=cut
