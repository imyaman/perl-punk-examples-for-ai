package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- Problem Details (RFC 7807) 에러 ----
any '/fail/400' => sub {
    my ($c) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Bad Request',
        status => 400,
        detail => 'missing required field',
    }, 400);
};

any '/fail/404' => sub {
    my ($c) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Not Found',
        status => 404,
        detail => 'resource does not exist',
        instance => '/fail/404',
    }, 404);
};

any '/fail/422' => sub {
    my ($c) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Unprocessable Entity',
        status => 422,
        detail => 'validation failed',
        errors => [{ field => 'email', issue => 'invalid format' }],
    }, 422);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 38: RFC 7807 Problem Details)

=head1 SYNOPSIS

GET/POST /fail/400  400 application/problem+json
GET/POST /fail/404  404 application/problem+json
GET/POST /fail/422  422 application/problem+json

=cut
