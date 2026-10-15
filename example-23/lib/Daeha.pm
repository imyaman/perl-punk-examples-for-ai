package Daeha;

use Punk;
use JSON::PP;

# ---- 정적 파일 서빙: /static/* -> ./public/* ----
static '/static' => 'public';

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 23: static 정적 파일 서빙)

=head1 SYNOPSIS

GET /static/hello.txt   텍스트 파일
GET /static/data.json   JSON 파일
GET /static/index.html  HTML 파일
GET /api/ping|healthz|readyz  헬스체크

=cut
