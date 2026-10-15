package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %ORDERS;   # id => { id, customer, status, items => [ {id, sku, qty, price_cents} ] }
my $OSEQ = 0;
my $ISEQ = 0;

sub _total {
    my ($o) = @_;
    my $t = 0;
    $t += $_->{qty} * $_->{price_cents} for @{ $o->{items} };
    return $t;
}

sub _order_view {
    my ($o) = @_;
    return {
        id             => $o->{id},
        customer       => $o->{customer},
        status         => $o->{status},
        item_count     => scalar @{ $o->{items} },
        total_cents    => _total($o),
    };
}

post '/orders' => sub {
    my ($c) = @_;
    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $customer = defined $b->{customer} ? "$b->{customer}" : '';
    return $c->json({ error => 'customer required' }, 400) unless length $customer;
    my $id = ++$OSEQ;
    $ORDERS{$id} = { id => $id, customer => $customer, status => 'open', items => [] };
    return $c->json(_order_view($ORDERS{$id}), 201);
};

get '/orders/:id' => sub {
    my ($c) = @_;
    my $o = $ORDERS{ $c->param('id') };
    return $c->json({ error => 'unknown order' }, 404) unless $o;
    my $v = _order_view($o);
    $v->{items} = $o->{items};
    return $c->json($v);
};

get '/orders/:id/items' => sub {
    my ($c) = @_;
    my $o = $ORDERS{ $c->param('id') };
    return $c->json({ error => 'unknown order' }, 404) unless $o;
    return $c->json({ order_id => $o->{id}, count => scalar @{ $o->{items} }, items => $o->{items} });
};

post '/orders/:id/items' => sub {
    my ($c) = @_;
    my $o = $ORDERS{ $c->param('id') };
    return $c->json({ error => 'unknown order' }, 404) unless $o;
    return $c->json({ error => 'order is not open' }, 409) unless $o->{status} eq 'open';

    my $b = $c->req->json // {};
    $b = {} unless ref $b eq 'HASH';
    my $sku = defined $b->{sku} ? "$b->{sku}" : '';
    return $c->json({ error => 'sku required' }, 400) unless length $sku;

    my $qty = $b->{qty};
    return $c->json({ error => 'qty must be an integer >= 1' }, 400)
        unless defined $sku && defined $qty && $sku ne '' && $sku =~ /^\S+$/ && $qty =~ /^\d+$/ && $qty >= 1;

    my $price = $b->{price_cents} // 0;
    return $c->json({ error => 'price_cents must be a non-negative integer' }, 400)
        unless $price =~ /^\d+$/;

    my $item = { id => ++$ISEQ, sku => $sku, qty => 0 + $qty, price_cents => 0 + $price };
    push @{ $o->{items} }, $item;
    return $c->json($item, 201);
};

del '/orders/:id/items/:itemId' => sub {
    my ($c) = @_;
    my $o = $ORDERS{ $c->param('id') };
    return $c->json({ error => 'unknown order' }, 404) unless $o;
    return $c->json({ error => 'order is not open' }, 409) unless $o->{status} eq 'open';

    my $item_id = $c->param('itemId');
    my $before = scalar @{ $o->{items} };
    $o->{items} = [ grep { $_->{id} != $item_id } @{ $o->{items} } ];
    return $c->json({ error => 'unknown item' }, 404) if @{ $o->{items} } == $before;
    return $c->text('', 204);
};

post '/orders/:id/submit' => sub {
    my ($c) = @_;
    my $o = $ORDERS{ $c->param('id') };
    return $c->json({ error => 'unknown order' }, 404) unless $o;
    return $c->json({ error => 'order is not open' }, 409) unless $o->{status} eq 'open';
    return $c->json({ error => 'order has no items', code => 'empty_order' }, 422)
        unless @{ $o->{items} };
    $o->{status} = 'submitted';
    return $c->json(_order_view($o));
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 91: 중첩 하위 리소스)

=head1 SYNOPSIS

POST   /orders                    주문 생성
POST   /orders/:id/items          항목 추가
GET    /orders/:id/items          항목 목록
DELETE /orders/:id/items/:itemId  항목 삭제
POST   /orders/:id/submit         제출

=cut
