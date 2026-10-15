package Daeha;

use Punk;
use JSON::PP;

my $DRAINING  = 0;
my $IN_FLIGHT = 0;

hook before_dispatch => sub { $IN_FLIGHT++; return };

hook after_dispatch => sub {
    $IN_FLIGHT-- if $IN_FLIGHT > 0;
    return;
};

# ---- 라이브니스: 프로세스가 살아있는가 (드레인 중에도 200) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };

# ---- 레디니스: 트래픽을 받을 준비가 됐는가 ----
get '/api/readyz' => sub {
    my ($c) = @_;
    if ($DRAINING) {
        return $c->json({ status => 'draining', ready => JSON::PP::false, reason => 'shutting down' }, 503);
    }
    return $c->json({ status => 'ready', ready => JSON::PP::true, in_flight => $IN_FLIGHT });
};

get '/work' => sub {
    my ($c) = @_;
    return $c->json({ ok => 1, in_flight => $IN_FLIGHT });
};

# ---- 운영 제어 ----
post '/admin/drain' => sub {
    my ($c) = @_;
    $DRAINING = 1;
    return $c->json({ draining => JSON::PP::true, in_flight => $IN_FLIGHT });
};

post '/admin/resume' => sub {
    my ($c) = @_;
    $DRAINING = 0;
    return $c->json({ draining => JSON::PP::false });
};

get '/admin/state' => sub {
    my ($c) = @_;
    return $c->json({ draining => $DRAINING ? JSON::PP::true : JSON::PP::false, in_flight => $IN_FLIGHT });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 87: 그레이스풀 드레인)

=head1 SYNOPSIS

POST /admin/drain   새 트래픽 거부 시작(readyz 503)
POST /admin/resume  복귀
GET  /api/readyz    준비 상태

=cut
