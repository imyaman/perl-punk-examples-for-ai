package Daeha;

use Punk;
use JSON::PP;

# ---- before_dispatch: 요청마다 request id 부여 ----
hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('x-request-id');
    $rid = 'req-' . int(rand(1_000_000)) unless defined $rid && length $rid;
    $c->stash->{rid} = $rid;
    return;   # 응답을 반환하지 않으면 계속 진행
};

# ---- after_dispatch: 완성된 응답에 헤더 추가 ----
hook after_dispatch => sub {
    my ($c, $resp) = @_;
    my $headers = $resp->[1];
    push @$headers, 'X-Request-Id' => ($c->stash->{rid} // 'unknown');
    return $resp;
};

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 훅 효과를 드러내는 핸들러 ----
get '/api/whoami' => sub {
    my ($c) = @_;
    $c->json({ request_id => $c->stash->{rid} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 11: hook before_dispatch / after_dispatch)

=head1 SYNOPSIS

GET /api/whoami     요청마다 부여된 request id 확인
GET /api/ping|healthz|readyz  헬스체크

모든 응답에 X-Request-Id 헤더가 추가됩니다.

=cut
