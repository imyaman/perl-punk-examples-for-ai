package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(hmac_sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $SECRET = 'whsec_demo';
my %SEEN;                       # event_id -> 1 (처리 완료)

sub _verify {
    my ($raw, $sig) = @_;
    return 0 unless defined $sig;
    $sig =~ s/^sha256=//;
    my $expect = hmac_sha256_hex($raw, $SECRET);
    return 0 unless length($sig) == length($expect);
    my $diff = 0;
    $diff |= ord(substr($sig, $_, 1)) ^ ord(substr($expect, $_, 1)) for 0 .. length($expect) - 1;
    return $diff == 0 ? 1 : 0;
}

post '/webhooks/events' => sub {
    my ($c) = @_;

    my $raw = $c->req->body // '';
    my $sig = $c->req->header('x-signature');

    unless (_verify($raw, $sig)) {
        return $c->json({ error => 'invalid signature' }, 401);
    }

    my $body = eval { JSON::PP->new->decode($raw) } || {};
    my $eid  = $body->{id};
    unless (defined $eid && length $eid) {
        return $c->json({ error => 'missing event id' }, 400);
    }

    if ($SEEN{$eid}) {
        return $c->json({ received => 1, duplicate => 1, id => $eid });
    }
    $SEEN{$eid} = 1;

    return $c->json({ received => 1, duplicate => 0, id => $eid });
};

get '/webhooks/seen' => sub {
    my ($c) = @_;
    return $c->json({ count => scalar keys %SEEN, ids => [ sort keys %SEEN ] });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 61: 웹훅 수신 + 서명 검증 + 중복 제거)

=head1 SYNOPSIS

POST /webhooks/events  X-Signature: sha256=<hmac> 검증, 이벤트 ID 중복 무시

=cut
