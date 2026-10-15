package Daeha;

use Punk;
use JSON::PP;
use Time::HiRes ();

# ---- middleware: 가장 바깥 PSGI 래퍼 ----
middleware sub {
    my ($app) = @_;
    return sub {
        my ($env) = @_;
        my $start = Time::HiRes::time();
        my $res = $app->($env);
        my $ms = int((Time::HiRes::time() - $start) * 1000);
        if (ref $res->[1] eq 'ARRAY') {
            push @{ $res->[1] }, 'X-Runtime-Ms' => $ms;
        }
        return $res;
    };
};

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 미들웨어가 감싸는 일반 핸들러 ----
get '/api/work' => sub {
    my ($c) = @_;
    $c->json({ did => 'work', items => [ 1, 2, 3 ] });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 12: middleware PSGI 래퍼)

=head1 SYNOPSIS

GET /api/work                 응답 헤더 X-Runtime-Ms 확인
GET /api/ping|healthz|readyz  헬스체크

모든 응답에 처리시간(ms) 헤더 X-Runtime-Ms 가 추가됩니다.

=cut
