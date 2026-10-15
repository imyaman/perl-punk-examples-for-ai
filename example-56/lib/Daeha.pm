package Daeha;

use Punk;
use JSON::PP;
use POSIX qw(strftime);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

sub _http_date { strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime($_[0])) }

# ---- 구버전(폐기 예정) ----
get '/v1/legacy' => sub {
    my ($c) = @_;
    my $sunset = _http_date(time + 90 * 24 * 3600);   # 90일 후
    $c->header('Deprecation' => 'true');
    $c->header('Sunset' => $sunset);
    $c->header('Link' => '</v2/modern>; rel="successor-version"');
    $c->header('Warning' => '299 - "This endpoint is deprecated; use /v2/modern"');
    return $c->json({ ok => 1, deprecated => 1 });
};

# ---- 신버전 ----
get '/v2/modern' => sub {
    $_[0]->json({ ok => 1, version => 2 });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 56: 폐기 예정 API 고지 헤더)

=head1 SYNOPSIS

GET /v1/legacy   Deprecation/Sunset/Link(successor-version) 헤더와 함께 응답
GET /v2/modern   대체 엔드포인트

=cut
