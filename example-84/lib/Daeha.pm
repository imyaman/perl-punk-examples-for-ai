package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %JOBS;      # id => job
my @QUEUE;     # 처리 대기 중인 job id (FIFO)
my $SEQ = 0;
my $MAX_ATTEMPTS = 2;

# 작업 실행: (결과, 오류) 반환
sub _process {
    my ($job) = @_;
    my $type = $job->{type};
    my $p = $job->{payload} // {};

    if ($type eq 'sum') {
        my $n = $p->{numbers};
        return (undef, 'numbers must be a non-empty array')
            unless ref $n eq 'ARRAY' && @$n;
        return (undef, 'numbers must be numeric')
            if grep { !defined $_ || $_ !~ /^-?\d+(?:\.\d+)?$/ } @$n;
        my $sum = 0;
        $sum += $_ for @$n;
        return ($sum, undef);
    }
    if ($type eq 'fail') {
        return (undef, 'task failed');
    }
    return (undef, "unknown task type: $job->{type}");
}

post '/jobs' => sub {
    my ($c) = @_;
    my $b = $c->req->json;
    $b = {} unless ref $b eq 'HASH';
    my $type = defined $b->{type} ? "$b->{type}" : '';
    return $c->json({ error => 'type required' }, 400) unless length $type;

    my $id = sprintf('j-%04d', ++$SEQ);
    my $payload = ref $b->{payload} eq 'HASH' ? $b->{payload} : {};
    $JOBS{$id} = {
        id => $id, type => $type, payload => $payload,
        status => 'queued', attempts => 0, max_attempts => $MAX_ATTEMPTS,
    };
    push @QUEUE, $id;

    $c->header('Location' => "/jobs/$id");
    return $c->json({ id => $id, status => 'queued', poll => "/jobs/$id" }, 202);
};

post '/worker/tick' => sub {
    my ($c) = @_;
    my $id = shift @QUEUE;
    return $c->json({ processed => JSON::PP::null }) unless defined $id;

    my $job = $JOBS{$id};
    $job->{status}   = 'running';
    $job->{attempts}++;

    my ($res, $err) = _process($job);
    if (defined $err) {
        $job->{error} = $err;
        if ($job->{attempts} < $job->{max_attempts}) {
            $job->{status} = 'queued';
            push @QUEUE, $id;   # 재시도 대기열로
        } else {
            $job->{status} = 'failed';
        }
    } else {
        $job->{result} = $res;
        delete $job->{error};
        $job->{status} = 'done';
    }

    return $c->json({ processed => $id, status => $job->{status}, attempts => $job->{attempts} });
};

get '/jobs' => sub {
    my ($c) = @_;
    my %count;
    $count{ $JOBS{$_}{status} }++ for keys %JOBS;
    my @out = map {
        +{ id => $JOBS{$_}{id}, status => $JOBS{$_}{status}, attempts => $JOBS{$_}{attempts} }
    } sort keys %JOBS;
    return $c->json({ total => scalar @out, queued => scalar @QUEUE, by_status => \%count, jobs => \@out });
};

get '/jobs/:id' => sub {
    my ($c) = @_;
    my $job = $JOBS{$c->param('id')};
    return $c->json({ error => 'unknown job' }, 404) unless $job;
    return $c->json($job);
};

post '/jobs/:id/retry' => sub {
    my ($c) = @_;
    my $job = $JOBS{$c->param('id')};
    return $c->json({ error => 'unknown job' }, 404) unless $job;
    return $c->json({ error => 'job is not failed' }, 409) unless $job->{status} eq 'failed';

    $job->{status}   = 'queued';
    $job->{attempts} = 0;
    delete $job->{error};
    push @QUEUE, $job->{id};
    return $c->json({ id => $job->{id}, status => $job->{status} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 84: 작업 큐 + 워커 + 재시도)

=head1 SYNOPSIS

POST /jobs          큐에 적재
POST /worker/tick   큐에서 하나 처리
GET  /jobs[/:id]    상태 조회
POST /jobs/:id/retry 실패 작업 재시도

=cut
