package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @EVENTS;
my $SEQ = 0;

post '/events' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $type = defined $b->{type} ? "$b->{type}" : '';
    return $c->json({ error => 'type required' }, 400) unless length $type;
    my $ev = { id => ++$SEQ, type => $type, at => time() };
    push @EVENTS, $ev;
    return $c->json($ev, 201);
};

get '/events' => sub {
    my ($c) = @_;
    return $c->json({ count => scalar @EVENTS, events => \@EVENTS });
};

sub _next {
    my ($since) = @_;
    my ($ev) = grep { $_->{id} > $since } @EVENTS;
    return $ev;
}

# 롱폴링: since 이후 이벤트가 있으면 즉시, 없으면 timeout 까지 대기 후 204.
get '/wait' => sub {
    my ($c) = @_;

    my $since = $c->param('since');
    $since = 0 unless defined $since;
    return $c->json({ error => 'since must be a non-negative integer' }, 400)
        unless $since =~ /^\d+$/;

    my $timeout_ms = $c->param('timeout_ms');
    $timeout_ms = 1000 unless defined $timeout_ms;
    return $c->json({ error => 'timeout_ms must be 1..30000' }, 400)
        unless $timeout_ms =~ /^\d+$/ && $timeout_ms >= 1 && $timeout_ms <= 30000;

    if (my $ev = _next($since)) {
        return $c->json({ event => $ev, waited => 0 });
    }

    my $p = $c->promise;
    $c->timer($timeout_ms / 1000)->on_done(sub {
        my $ev = _next($since);
        $p->done($ev ? $c->json({ event => $ev, waited => $timeout_ms })
                     : $c->text('', 204));
    });
    return $p;
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 97: 롱폴링)

=head1 SYNOPSIS

POST /events   이벤트 적재
GET  /wait     since 이후 이벤트 대기(timeout 까지)

=cut
