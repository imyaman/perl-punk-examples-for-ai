package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $WINDOW        = 86400;    # 하루 고정 창
my $DEFAULT_LIMIT = 5;

my %USAGE;   # key => { used, limit, period_start }

sub _key  { my ($c) = @_; return $c->req->header('X-Api-Key') }
sub _period_start { return int(time() / 86400) * 86400 }
sub _period_end   { return _period_start() + 86400 }

sub _slot {
    my ($key) = @_;
    my $u = $USAGE{$key};
    if (!$u) {
        $u = { used => 0, limit => $DEFAULT_LIMIT, period => _period_start() };
        $USAGE{$key} = $u;
    }
    if (($u->{period} // 0) != _period_start()) {   # 기간이 바뀌면 리셋
        $u->{used}   = 0;
        $u->{period} = _period_start();
    }
    return $u;
}

# ---- 계량 대상 엔드포인트 ----
get '/api/data' => sub {
    my ($c) = @_;
    my $key = _key($c);
    return $c->json({ error => 'missing API key' }, 401) unless defined $key && length $key;

    my $u = _slot($key);
    my $limit = $u->{limit};

    if ($u->{used} >= $limit) {
        my $retry = _period_start() + 86400 - time();
        $c->header('Retry-After'   => $retry);
        $c->header('X-Usage-Limit' => $limit);
        $c->header('X-Usage-Used'  => $u->{used});
        return $c->json({ error => 'quota exceeded', used => $u->{used}, limit => $limit }, 429);
    }

    $u->{used}++;
    my $remaining = $limit - $u->{used};
    $c->header('X-Usage-Limit'     => $limit);
    $c->header('X-Usage-Used'      => $u->{used});
    $c->header('X-Usage-Remaining' => $remaining);
    return $c->json({ ok => 1, used => $u->{used}, limit => $limit, remaining => $remaining });
};

get '/usage' => sub {
    my ($c) = @_;
    my $key = $c->param('key');
    return $c->json({ error => 'key required' }, 400) unless defined $key && length $key;
    my $u = _slot($key);
    my $limit = $u->{limit};
    return $c->json({
        key       => $key,
        used      => $u->{used},
        limit     => $limit,
        remaining => ($limit - $u->{used} > 0 ? $limit - $u->{used} : 0),
        period    => $u->{period},
        period_end => _period_start() + 86400,
    });
};

# ---- 운영: 한도 설정 / 리셋 ----
put '/quota' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $key = defined $b->{key} ? "$b->{key}" : '';
    return $c->json({ error => 'key required' }, 400) unless length $key;
    my $limit = $b->{limit};
    return $c->json({ error => 'limit must be a positive integer' }, 400)
        unless defined $limit && $limit =~ /^\d+$/ && $limit >= 1;

    my $u = _slot($key);
    $u->{limit} = 0 + $limit;
    return $c->json({ key => $key, limit => $u->{limit}, used => $u->{used} });
};

post '/quota/reset' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $key = defined $b->{key} ? "$b->{key}" : '';
    return $c->json({ error => 'key required' }, 400) unless length $key;
    my $u = _slot($key);
    $u->{used} = 0;
    return $c->json({ key => $key, used => 0, limit => $u->{limit} });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 89: 사용량 계량 + 쿼터)

=head1 SYNOPSIS

GET  /api/data     API 키로 호출, 쿼터 소모
GET  /usage?key=   사용량 조회
PUT  /quota        한도 설정
POST /quota/reset  사용량 리셋

=cut
