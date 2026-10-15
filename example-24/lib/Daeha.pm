package Daeha;

use Punk;
use JSON::PP;

# ---- 마크다운 문서 사이트: /docs/* -> ./docs/*.md ----
markdown '/docs' => 'docs', title => 'Daeha Guide';

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 24: markdown 문서 사이트)

=head1 SYNOPSIS

GET /docs                  docs/index.md 렌더
GET /docs/getting-started  docs/getting-started.md 렌더
GET /api/ping|healthz|readyz  헬스체크

=cut
