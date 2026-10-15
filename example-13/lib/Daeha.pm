package Daeha;

use Punk;
use JSON::PP;

# ---- on_error: 가드/핸들러가 die 했을 때 커스텀 에러 응답 ----
on_error sub {
    my ($c, $err) = @_;
    my $msg = defined $err ? "$err" : 'unknown error';
    $msg =~ s/\s+\z//;
    return $c->json({
        error => { code => 'INTERNAL', message => $msg },
    }, 500);
};

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 정상 핸들러 ----
get '/api/ok' => sub {
    my ($c) = @_;
    $c->json({ ok => 1 });
};

# ---- 의도적으로 die 하는 핸들러 ----
get '/api/boom' => sub {
    diag_helper('about to fail');   # 미정의 서브 호출 -> die
    $_[0]->json({ never => 'reached' });
};

sub diag_helper { die "kaboom: something went wrong\n" }

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 13: on_error 커스텀 에러 핸들러)

=head1 SYNOPSIS

GET /api/ok      정상 200
GET /api/boom    die -> on_error 가 500 JSON 응답
GET /api/ping|healthz|readyz  헬스체크

=cut
