package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 가드: X-API-Key 가 맞아야 통과 ----
my $require_key = sub {
    my ($c) = @_;
    my $key = $c->req->header('x-api-key') // '';
    if ($key eq '') {
        return $c->json({ error => 'api key required' }, 401);
    }
    if ($key ne 'secret-key') {
        return $c->json({ error => 'invalid api key' }, 403);
    }
    $c->stash->{auth} = { owner => 'alice' };
    return;   # 응답을 반환하지 않으면 다음 단계로 진행
};

my $admin = under '/api/admin' => $require_key;

$admin->get('/dashboard' => sub {
    my ($c) = @_;
    $c->json({ scope => 'admin', owner => $c->stash->{auth}{owner}, widgets => 7 });
});

$admin->get('/users' => sub {
    my ($c) = @_;
    $c->json({ users => ['alice', 'bob', 'carol'] });
});

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 9: under 가드로 인증 통제)

=head1 SYNOPSIS

GET /api/admin/dashboard  X-API-Key 필요
GET /api/admin/users      X-API-Key 필요
GET /api/ping|healthz|readyz  헬스체크

유효 키: secret-key

=cut
