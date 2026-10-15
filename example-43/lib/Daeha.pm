package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 인메모리 충전 생성(idempotent) ----
my $CHARGE_ID = 0;
my %CACHE;  # key => { status => ..., body => \%hash, location => ..., ts => time }

sub _err400 {
    my ($c, $msg) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Bad Request',
        status => 400,
        detail => $msg,
    }, 400);
}

post '/charge' => sub {
    my ($c) = @_;
    my $key = $c->req->header('idempotency-key');
    return _err400($c, 'Idempotency-Key header is required') unless defined $key && $key ne '';

    if (exists $CACHE{$key}) {
        my $cached = $CACHE{$key};
        $c->header('Idempotent-Replayed' => 'true');
        $c->header('Location' => $cached->{location}) if $cached->{location};
        return $c->json($cached->{body}, $cached->{status});
    }

    $CHARGE_ID++;
    my $body = { charge_id => $CHARGE_ID, status => 'paid', amount => 1000 };
    my $location = "/charge/$CHARGE_ID";
    $c->header('Idempotent-Replayed' => 'false');
    $c->header('Location' => $location);
    my $resp = { status => 201, body => $body, location => $location, ts => time };
    $CACHE{$key} = $resp;
    return $c->json($body, 201);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 43: Idempotency-Key)

=head1 SYNOPSIS

POST /charge  헤더 Idempotency-Key 필수. 같은 키 재전송 시 같은 결과 재생

=cut
