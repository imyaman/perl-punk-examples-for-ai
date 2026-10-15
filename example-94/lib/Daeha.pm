package Daeha;

use Punk;
use JSON::PP;
use Time::HiRes ();

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $WINDOW = 2;    # 초
my $LIMIT  = 5;
my %HITS;          # key => [ 타임스탬프... ]

sub _now { Time::HiRes::time() }

sub _key {
    my ($c) = @_;
    my $k = $c->req->header('X-API-Key');
    return (defined $k && length $k) ? $k : 'anon';
}

get '/api/hit' => sub {
    my ($c) = @_;
    my $key  = _key($c);
    my $now  = _now();
    my $edge = $now - $WINDOW;

    my $log = $HITS{$key} ||= [];
    @$log = grep { $_ > $edge } @$log;    # 윈도우 밖 제거

    my $reset = @$log ? $log->[0] + $WINDOW : $now + $WINDOW;

    if (@$log >= $LIMIT) {
        my $retry = $log->[0] + $WINDOW - $now;
        $retry = 0 if $retry < 0;
        $c->header('Retry-After'           => sprintf('%.2f', $retry));
        $c->header('X-RateLimit-Limit'     => $LIMIT);
        $c->header('X-RateLimit-Remaining' => 0);
        $c->header('X-RateLimit-Reset'     => int($reset));
        return $c->json({ error => 'rate limit exceeded', limit => $LIMIT, window => $WINDOW }, 429);
    }

    push @$log, $now;
    $c->header('X-RateLimit-Limit'     => $LIMIT);
    $c->header('X-RateLimit-Remaining' => $LIMIT - scalar @$log);
    $c->header('X-RateLimit-Reset'     => int($reset));
    return $c->json({ ok => 1, used => scalar @$log, limit => $LIMIT });
};

get '/ratelimit' => sub {
    my ($c) = @_;
    return $c->json({ window => $WINDOW, limit => $LIMIT });
};

put '/ratelimit' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    if (defined $b->{window}) {
        return $c->json({ error => 'window must be > 0' }, 400)
            unless $b->{window} =~ /^\d+(?:\.\d+)?$/ && $b->{window} > 0;
        $WINDOW = 0 + $b->{window};
    }
    if (defined $b->{limit}) {
        return $c->json({ error => 'limit must be a positive integer' }, 400)
            unless $b->{limit} =~ /^\d+$/ && $b->{limit} >= 1;
        $LIMIT = 0 + $b->{limit};
    }
    %HITS = ();   # 설정 변경 시 초기화
    return $c->json({ window => $WINDOW, limit => $LIMIT });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 94: 슬라이딩 윈도우 레이트 리밋)

=head1 SYNOPSIS

GET /api/hit      요청, 한도 초과 시 429
PUT /ratelimit    윈도우/한도 설정

=cut
