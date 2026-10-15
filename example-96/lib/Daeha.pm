package Daeha;

use Punk;
use JSON::PP;
use Time::HiRes ();

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $mode      = 'ok';      # 다운스트림 동작 시뮬레이션: ok | fail
my $threshold = 3;
my $open_secs = 1;

my $state     = 'closed';  # closed | open | half_open
my $failures  = 0;
my $opened_at = 0;

sub _now { Time::HiRes::time() }
sub _downstream { return $mode eq 'ok' ? 1 : 0 }

get '/api/fetch' => sub {
    my ($c) = @_;

    # OPEN: 하위 호출을 시도조차 하지 않고 즉시 차단
    if ($state eq 'open') {
        my $elapsed = _now() - $opened_at;
        if ($elapsed >= $open_secs) {
            $state = 'half_open';    # 시험 호출 허용
        } else {
            my $retry = $open_secs - $elapsed;
            $retry = 0 if $retry < 0;
            $c->header('Retry-After' => sprintf('%.2f', $retry));
            return $c->json({ error => 'circuit open', state => 'open' }, 503);
        }
    }

    if (_downstream()) {
        $state    = 'closed';
        $failures = 0;
        return $c->json({ ok => 1, state => $state });
    }

    $failures++;
    if ($state eq 'half_open' || $failures >= $threshold) {
        $state     = 'open';         # 임계 초과 또는 시험 실패 -> 다시 차단
        $opened_at = _now();
    }
    return $c->json({ error => 'downstream failed', state => $state, failures => $failures }, 502);
};

get '/circuit' => sub {
    my ($c) = @_;
    return $c->json({
        state     => $state,
        failures  => $failures,
        threshold => $threshold,
        open_secs => $open_secs,
    });
};

post '/downstream/mode' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $m = defined $b->{mode} ? "$b->{mode}" : '';
    return $c->json({ error => 'mode must be ok or fail' }, 400)
        unless $m eq 'ok' || $m eq 'fail';
    $mode = $m;
    return $c->json({ mode => $mode });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 96: 서킷 브레이커)

=head1 SYNOPSIS

GET  /api/fetch          하위 호출 (실패 누적 시 회로 차단)
GET  /circuit            회로 상태
POST /downstream/mode    하위 상태 시뮬레이션

=cut
