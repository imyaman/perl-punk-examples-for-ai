package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 고정 윈도우 레이트 리밋 ----
my $LIMIT  = 3;
my $WINDOW = 10;      # 초
my %BUCKET;           # client => { count => n, reset => epoch }

sub _client {
    my ($c) = @_;
    my $fwd = $c->req->header('x-forwarded-for');
    return $fwd if defined $fwd && length $fwd;
    return $c->env->{REMOTE_ADDR} // 'unknown';
}

get '/limited' => sub {
    my ($c) = @_;
    my $now = time;
    my $id  = _client($c);

    my $b = $BUCKET{$id};
    if (!$b || $now >= $b->{reset}) {
        $b = { count => 0, reset => $now + $WINDOW };
        $BUCKET{$id} = $b;
    }
    $b->{count}++;

    my $remaining = $LIMIT - $b->{count};
    $remaining = 0 if $remaining < 0;

    $c->header('X-RateLimit-Limit'     => $LIMIT);
    $c->header('X-RateLimit-Remaining' => $remaining);
    $c->header('X-RateLimit-Reset'     => $b->{reset});

    if ($b->{count} > $LIMIT) {
        my $retry = $b->{reset} - $now;
        $retry = 0 if $retry < 0;
        $c->header('Retry-After' => $retry);
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Too Many Requests',
            status => 429,
            detail => "rate limit of $LIMIT per ${WINDOW}s exceeded",
        }, 429);
    }

    return $c->json({ ok => 1, count => $b->{count}, remaining => $remaining });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 47: 레이트 리밋)

=head1 SYNOPSIS

GET /limited  IP당 10초에 3회까지. 초과시 429 + Retry-After

=cut
