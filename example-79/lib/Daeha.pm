package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $MAX_ATTEMPTS = 3;   # 최대 시도 횟수
my $BACKOFF_BASE = 1;   # 지수 백오프 초 (1,2,4,...)

my $SINK_MODE = 'ok';   # ok | fail  (테스트용 수신기 모드)
my @SINK;               # 수신한 이벤트
my %JOBS;               # id => job
my @DEAD;               # 디드레터 페이로드
my $SEQ = 0;

sub _base {
    my ($c) = @_;
    my $host = $c->env->{HTTP_HOST} // $c->env->{SERVER_NAME} // '127.0.0.1';
    return "http://$host";
}

sub _problem {
    my ($c, $status, $title, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({ type => 'about:blank', title => $title, status => $status,
                      (defined $detail ? (detail => $detail) : ()) }, $status);
}

# ---- 테스트용 수신기(구독자 역할) ----
post '/hook/sink' => sub {
    my ($c) = @_;
    return $c->json({ error => 'sink down' }, 500) if $SINK_MODE eq 'fail';
    push @SINK, $c->req->json;
    return $c->json({ ok => 1, received => scalar @SINK });
};

post '/hook/sink/mode' => sub {
    my ($c) = @_;
    my $b = $c->req->json;
    $b = {} unless ref $b eq 'HASH';
    my $m = defined $b->{mode} ? "$b->{mode}" : '';
    return _problem($c, 400, 'Bad Request', 'mode must be ok or fail')
        unless $m eq 'ok' || $m eq 'fail';
    $SINK_MODE = $m;
    return $c->json({ mode => $SINK_MODE });
};

get '/hook/sink' => sub {
    my ($c) = @_;
    return $c->json({ mode => $SINK_MODE, count => scalar @SINK, received => \@SINK });
};

# ---- 전송(재시도 + 디드레터) ----
sub _deliver {
    my ($c, $job) = @_;
    $job->{attempts_log} = [];
    delete $job->{next_retry_at};

    for my $i (1 .. $MAX_ATTEMPTS) {
        $job->{attempts} = $i;

        my ($status, $err);
        my $res = eval {
            $c->ua->post(_base($c) . '/hook/sink', json => {
                event_id => $job->{id},
                attempt  => $i,
                payload  => $job->{payload},
            })->get;
        };
        if ($res) { $status = $res->status }
        else      { $err   = $@ || 'transport error' }

        my $ok = defined $status && $status >= 200 && $status < 300;
        push @{ $job->{attempts_log} }, {
            attempt => $i,
            ts      => time(),
            ok      => $ok ? 1 : 0,
            (defined $status ? (status => $status + 0) : (error => "$err")),
        };
        last if $ok;
        # 다음 시도까지의 지수 백오프(초). 여기서는 기록만 하고 실제로는 기다리지 않음.
        $job->{next_retry_at} = time() + ($BACKOFF_BASE * (2 ** ($i - 1)))
            if $i < $MAX_ATTEMPTS;
    }

    my $delivered = $job->{attempts_log}[-1]{ok};
    $job->{state} = $delivered ? 'delivered' : 'dead_letter';
    delete $job->{next_retry_at};

    if (!$delivered) {
        push @DEAD, {
            id       => $job->{id},
            attempts => $job->{attempts},
            payload  => $job->{payload},
            dead_at  => time(),
        };
    }
    return $delivered;
}

post '/events' => sub {
    my ($c) = @_;
    my $b = $c->req->json;
    $b = {} unless ref $b eq 'HASH';
    return _problem($c, 400, 'Bad Request', 'payload must be an object')
        unless ref $b->{payload} eq 'HASH';

    $SEQ++;
    my $job = {
        id          => sprintf('job-%04d', $SEQ),
        state       => 'pending',
        attempts    => 0,
        payload     => $b->{payload},
        created_at  => time(),
        attempts_log => [],
    };
    $JOBS{$job->{id}} = $job;
    _deliver($c, $job);

    $c->header('Location' => "/jobs/$job->{id}");
    return $c->json({
        id       => $job->{id},
        state    => $job->{state},
        attempts => $job->{attempts},
        poll     => "/jobs/$job->{id}",
    }, 202);
};

get '/jobs' => sub {
    my ($c) = @_;
    my @out = map {
        { id => $_, state => $JOBS{$_}{state}, attempts => $JOBS{$_}{attempts} }
    } sort keys %JOBS;
    return $c->json({ jobs => \@out });
};

get '/jobs/:id' => sub {
    my ($c) = @_;
    my $j = $JOBS{$c->param('id')};
    return _problem($c, 404, 'Not Found', 'unknown job') unless $j;
    return $c->json($j);
};

get '/dead-letters' => sub {
    my ($c) = @_;
    return $c->json({ count => scalar @DEAD, dead_letters => \@DEAD });
};

post '/dead-letters/:id/retry' => sub {
    my ($c) = @_;
    my $j = $JOBS{$c->param('id')};
    return _problem($c, 404, 'Not Found', 'unknown job') unless $j;
    return _problem($c, 409, 'Conflict', 'job is not in dead_letter state')
        unless $j->{state} eq 'dead_letter';

    @DEAD = grep { $_->{id} ne $j->{id} } @DEAD;
    $j->{state}    = 'pending';
    $j->{attempts} = 0;
    _deliver($c, $j);
    return $c->json({ id => $j->{id}, state => $j->{state}, attempts => $j->{attempts} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 79: 아웃바운드 웹훅 재시도 + 디드레터)

=head1 SYNOPSIS

POST /events                    이벤트 전송(최대 3회 재시도, 지수 백오프)
GET  /jobs[/:id]                전송 상태
GET  /dead-letters              소진된 페이로드
POST /dead-letters/:id/retry    디드레터 재전송

=cut
