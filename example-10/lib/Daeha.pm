package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 순수 PSGI 서브앱 (Punk 밖의 코드) ----
my $legacy_app = sub {
    my ($env) = @_;
    my $body = JSON::PP->new->encode({
        legacy  => 1,
        method  => $env->{REQUEST_METHOD},
        path    => $env->{PATH_INFO},
        script  => $env->{SCRIPT_NAME},
    });
    return [ 200, [ 'Content-Type' => 'application/json' ], [ $body ] ];
};

# ---- 접두사 /legacy 로 PSGI 앱 마운트 ----
mount '/legacy' => $legacy_app;

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 10: mount 로 PSGI 서브앱 붙이기)

=head1 SYNOPSIS

ANY  /legacy/*        마운트된 순수 PSGI 앱으로 위임
GET  /api/ping|healthz|readyz  헬스체크

=cut
