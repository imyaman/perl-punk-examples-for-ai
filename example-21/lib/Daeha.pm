package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

# ---- 공유 비밀 (데모) ----
my $SECRET = 'webhook-shared-secret';

sub _secure_eq {
    my ($a, $b) = @_;
    return 0 if length($a) != length($b);
    my $r = 0;
    $r |= ord(substr($a, $_, 1)) ^ ord(substr($b, $_, 1)) for 0 .. length($a) - 1;
    return $r == 0;
}

# ---- 서명 검증 가드 ----
my $verify_signature = sub {
    my ($c) = @_;
    my $sig = $c->req->header('x-signature') // '';
    return $c->json({ error => 'missing signature' }, 401) unless length $sig;

    my $body   = $c->req->body // '';
    my $expect = 'sha256=' . hmac_sha256_hex($body, $SECRET);

    return $c->json({ error => 'bad signature' }, 401)
        unless _secure_eq($sig, $expect);

    return;
};

# ---- 헬스체크 (기준선, 공개) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 서명이 필요한 웹훅 구역 ----
my $hooks = under '/webhook' => $verify_signature;

$hooks->post('/event' => sub {
    my ($c) = @_;
    my $payload = eval { $c->req->json } // {};
    $c->json({ received => 1, event => $payload->{event} // 'unknown' });
});

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 21: HMAC 서명 검증)

=head1 SYNOPSIS

POST /webhook/event   X-Signature: sha256=<hmac(body)>
GET  /api/ping|healthz|readyz  헬스체크(공개)

서명: HMAC-SHA256(body, 'webhook-shared-secret')

=cut
