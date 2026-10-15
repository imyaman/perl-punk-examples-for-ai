package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 인메모리 리소스 하나 (메서드별 동작 시연) ----
my %ITEM = (id => 1, name => 'widget', qty => 5);

get '/api/item' => sub {
    my ($c) = @_;
    $c->json({ item => { %ITEM } });
};

post '/api/item' => sub {
    my ($c) = @_;
    my $in = eval { $c->req->json };
    if ($in && ref $in eq 'HASH' && defined $in->{name}) {
        $ITEM{name} = $in->{name};
    }
    $c->json({ created => 1, item => { %ITEM } }, 201);
};

put '/api/item' => sub {
    my ($c) = @_;
    my $in = eval { $c->req->json };
    return $c->json({ error => 'invalid JSON' }, 400)
        unless $in && ref $in eq 'HASH';
    $ITEM{name} = $in->{name} // $ITEM{name};
    $ITEM{qty}  = $in->{qty}  // $ITEM{qty};
    $c->json({ replaced => 1, item => { %ITEM } });
};

patch '/api/item' => sub {
    my ($c) = @_;
    my $in = eval { $c->req->json };
    return $c->json({ error => 'invalid JSON' }, 400)
        unless $in && ref $in eq 'HASH';
    $ITEM{$_} = $in->{$_} for keys %$in;
    $c->json({ patched => 1, changed => [ sort keys %$in ], item => { %ITEM } });
};

del '/api/item' => sub {
    my ($c) = @_;
    my $old = { %ITEM };
    %ITEM = (id => 1, name => 'widget', qty => 5);
    $c->json({ deleted => $old });
};

# ---- any: 모든 메서드에 응답 ----
any '/api/echo' => sub {
    my ($c) = @_;
    $c->json({ method => $c->req->method, path => $c->req->path });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 7: HTTP 메서드 get/post/put/patch/del/any)

=head1 SYNOPSIS

GET|POST|PUT|PATCH|DELETE /api/item  메서드별 동작
ANY                        /api/echo  모든 메서드 에코
GET /api/ping|healthz|readyz         헬스체크

=cut
