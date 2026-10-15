package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- v1 스코프 ----
my $v1 = under '/api/v1';

$v1->get('/status' => sub {
    my ($c) = @_;
    $c->json({ version => 'v1', status => 'live' });
});

$v1->get('/items' => sub {
    my ($c) = @_;
    $c->json({ version => 'v1', items => ['alpha', 'beta'] });
});

# ---- v2 스코프 ----
my $v2 = under '/api/v2';

$v2->get('/status' => sub {
    my ($c) = @_;
    $c->json({ version => 'v2', status => 'live', features => ['pagination'] });
});

# ---- 중첩 스코프: /api/v1/admin ----
my $admin = under '/api/v1/admin';

$admin->get('/stats' => sub {
    my ($c) = @_;
    $c->json({ scope => 'admin', users => 3, uptime => 1234 });
});

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 8: under 스코프/접두사 라우팅)

=head1 SYNOPSIS

GET /api/v1/status        v1 상태
GET /api/v1/items         v1 목록
GET /api/v2/status        v2 상태
GET /api/v1/admin/stats   중첩 스코프
GET /api/ping|healthz|readyz  헬스체크

=cut
