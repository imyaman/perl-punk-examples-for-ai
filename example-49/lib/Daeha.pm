package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 표현 형태 ----
sub _v1 {
    return { items => [ { id => 1, name => 'alpha' } ] };
}
sub _v2 {
    return { data => [ { id => 1, name => 'alpha', created_at => '2024-01-01T00:00:00Z' } ],
             meta => { version => 2 } };
}

# ---- URL prefix 버저닝 ----
get '/v1/items' => sub { $_[0]->json(_v1()) };
get '/v2/items' => sub { $_[0]->json(_v2()) };

# ---- Accept 헤더 버저닝 ----
get '/items' => sub {
    my ($c) = @_;
    my $accept = $c->req->header('accept') // '';
    if ($accept =~ m{application/vnd\.daeha\.v2\+json}) {
        $c->header('Content-Type' => 'application/vnd.daeha.v2+json');
        return $c->json(_v2());
    }
    if ($accept =~ m{application/vnd\.daeha\.v1\+json}) {
        $c->header('Content-Type' => 'application/vnd.daeha.v1+json');
        return $c->json(_v1());
    }
    return $c->json(_v1());
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 49: API 버저닝)

=head1 SYNOPSIS

GET /v1/items, /v2/items         URL prefix 버저닝
GET /items                       Accept: application/vnd.daeha.v2+json 로 v2

=cut
