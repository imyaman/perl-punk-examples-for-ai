package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 간단한 인-메모리 키-밸류 ----
my %KV = ();

# ---- 저장 (POST /kv/:key) ----
post '/kv/:key' => sub {
    my ($c) = @_;
    my $key = $c->param('key');
    my $body = $c->req->json // {};
    my $val = $body->{value};
    unless (defined $val) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Bad Request',
            status => 400,
            detail => 'value is required',
        }, 400);
    }
    $KV{$key} = $val;
    $c->header('Location' => "/kv/$key");
    return $c->json({ key => $key, value => $KV{$key} }, 201);
};

# ---- 조회 (GET /kv/:key) ----
get '/kv/:key' => sub {
    my ($c) = @_;
    my $key = $c->param('key');
    unless (exists $KV{$key}) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Not Found',
            status => 404,
            detail => 'key not found',
            instance => "/kv/$key",
        }, 404);
    }
    return $c->json({ key => $key, value => $KV{$key} });
};

# ---- 갱신 (PUT /kv/:key) ----
put '/kv/:key' => sub {
    my ($c) = @_;
    my $key = $c->param('key');
    my $body = $c->req->json // {};
    my $val = $body->{value};
    unless (defined $val) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Bad Request',
            status => 400,
            detail => 'value is required',
        }, 400);
    }
    $KV{$key} = $val;
    return $c->json({ key => $key, value => $KV{$key} });
};

# ---- 삭제 (DELETE /kv/:key) ----
del '/kv/:key' => sub {
    my ($c) = @_;
    my $key = $c->param('key');
    if (exists $KV{$key}) {
        delete $KV{$key};
        return $c->text('', 204);
    }
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Not Found',
        status => 404,
        detail => 'key not found',
        instance => "/kv/$key",
    }, 404);
};

# ---- 목록 (GET /kv) ----
get '/kv' => sub {
    my ($c) = @_;
    my @items = map { { key => $_, value => $KV{$_} } } sort keys %KV;
    return $c->json({ count => scalar @items, items => \@items });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 39: REST CRUD + 201/204)

=head1 SYNOPSIS

POST   /kv/:key  JSON {value:...} → 201 Created + Location
GET    /kv/:key  200 or 404
PUT    /kv/:key  JSON {value:...} → 200
DELETE /kv/:key  204 No Content (or 404)
GET    /kv       목록

=cut
