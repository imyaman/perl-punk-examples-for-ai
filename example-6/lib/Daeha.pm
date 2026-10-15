package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 단일 세그먼트 캡처: :id ----
get '/api/users/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    $c->json({ resource => 'user', id => $id });
};

# ---- 여러 캡처: :left / :right ----
get '/api/pairs/:left/:right' => sub {
    my ($c) = @_;
    $c->json({
        left  => $c->param('left'),
        right => $c->param('right'),
    });
};

# ---- 와일드카드: 나머지 전체를 *path 로 캡처 ----
get '/api/files/*path' => sub {
    my ($c) = @_;
    my $path = $c->param('path');
    $c->json({
        path     => $path,
        segments => [ split m{/}, $path ],
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 6: 라우트 캡처 :param / *splat)

=head1 SYNOPSIS

GET /api/users/:id           단일 세그먼트 캡처
GET /api/pairs/:left/:right  여러 캡처
GET /api/files/*path         나머지 경로 전체 캡처
GET /api/ping|healthz|readyz 헬스체크

=cut
