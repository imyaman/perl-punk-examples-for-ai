package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선, 즉시 응답) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- timer: 1초 뒤 응답 (워커를 붙잡지 않음) ----
get '/async/timer' => sub {
    my ($c) = @_;
    return $c->timer(1)->then(sub {
        $c->json({ ready => 1, how => 'timer' });
    });
};

# ---- promise: 나중에 외부에서 settle ----
get '/async/promise' => sub {
    my ($c) = @_;
    my $p = $c->promise;
    $c->after(1)->on_done(sub {
        $p->done($c->json({ ready => 1, how => 'promise' }));
    });
    return $p;
};

# ---- await: 명령형 탈출구 (future 결과를 값으로) ----
get '/async/await' => sub {
    my ($c) = @_;
    my ($value) = $c->await($c->timer(1)->then(sub { 42 }));
    $c->json({ ready => 1, how => 'await', value => $value });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 26: 비동기 timer/after/promise/await)

=head1 SYNOPSIS

GET /async/timer      $c->timer(1)->then(...)
GET /async/promise    $c->promise + $c->after(...)->on_done
GET /async/await      $c->await($future)
GET /api/ping|healthz|readyz  헬스체크

=cut
