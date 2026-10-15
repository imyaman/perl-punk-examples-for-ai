package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha1_hex);

# 요청마다 상관관계 ID(correlation id)를 부여한다.
hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('X-Correlation-Id');
    $rid = sha1_hex(time() . rand() . $$) unless defined $rid && length $rid;
    $rid = substr($rid, 0, 16);
    $c->stash->{rid} = $rid;
    $c->header('X-Correlation-Id' => $rid);
    return;
};

# 처리기/가드가 죽으면 여기서 일관된 problem+json 으로 변환한다.
on_error sub {
    my ($c, $err) = @_;
    my $rid = $c->stash->{rid} // 'none';
    warn "[error][$rid] $err\n";
    $c->res->status(500);
    $c->res->type('application/problem+json');
    return $c->res->body(JSON::PP->new->encode({
        type           => 'about:blank',
        title          => 'Internal Server Error',
        status         => 500,
        correlation_id => $rid,
        detail         => "$err",
    }));
};

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

get '/ok' => sub { $_[0]->json({ ok => 1 }) };

# 의도적으로 죽는 처리기들
get '/boom'    => sub { die "kaboom in handler\n" };
get '/divzero' => sub { my $x = 1 / 0; return $_[0]->json({ x => $x }) };
get '/chain'   => sub { _inner(); };
sub _inner { die "inner failure\n" }

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 93: 구조화된 에러 처리)

=head1 SYNOPSIS

GET /boom     처리기 예외 -> 500 problem+json
GET /ok       정상

=cut
