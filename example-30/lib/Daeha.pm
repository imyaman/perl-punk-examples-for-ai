package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 쿠키 설정 ----
get '/cookie/set' => sub {
    my ($c) = @_;
    $c->cookie('daeha' => 'tasty', path => '/', max_age => 3600, httponly => 1)
      ->json({ set => 1, value => 'tasty' });
};

# ---- 쿠키 읽기 ----
get '/cookie/read' => sub {
    my ($c) = @_;
    my $v = $c->cookie('daeha');
    $c->json({ present => defined $v ? 1 : 0, value => (defined $v ? $v : '') });
};

# ---- 쿠키 삭제 ----
get '/cookie/clear' => sub {
    my ($c) = @_;
    $c->cookie('daeha' => undef, path => '/')
      ->json({ cleared => 1 });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 30: 쿠키 설정/읽기/삭제)

=head1 SYNOPSIS

GET /cookie/set    Set-Cookie 로 쿠키 설정
GET /cookie/read   요청 쿠키 읽기
GET /cookie/clear  쿠키 삭제
GET /api/ping|healthz|readyz  헬스체크

=cut
