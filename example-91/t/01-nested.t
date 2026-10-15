#!/usr/bin/perl
use Test::More;
use JSON::PP;

my $BASE = 'http://127.0.0.1:3004';

sub _raw {
    my @cmd = @_;
    my $out = '';
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm(15);
        open(my $fh, "-|", @cmd) or die "open pipe: @cmd: $!";
        { local $/; $out = <$fh>; }
        close $fh;
        alarm(0);
    };
    return $@ ? '' : $out;
}
sub _req {
    my ($method, $path, $body) = @_;
    my @cmd = ('curl', '-s', '--max-time', '18', '-i', '-X', $method, "$BASE$path");
    if (defined $body) {
        push @cmd, '-H', 'Content-Type: application/json', '--data-raw', $body;
    }
    my $out = _raw(@cmd);
    my ($head, $b) = split /\r?\n\r?\n/, $out, 2;
    my $code;
    for my $line (split /\r?\n/, ($head // '')) {
        if ($line =~ m{^HTTP/\S+\s+(\d{3})}) { $code = $1; last }
    }
    return { code => $code, body => ($b // '') };
}
sub _json { JSON::PP->new->decode(shift->{body}) }
sub _j { JSON::PP->new->encode($_[0]) }

is(_req('GET','/api/ping')->{code}, '200', 'ping 200');

# 주문 생성
my $oid;
{
    my $r = _req('POST', '/orders', _j({ customer => 'alice' }));
    is($r->{code}, '201', 'order 201');
    my $d = _json($r);
    $oid = $d->{id};
    is($d->{status}, 'open', 'status open');
    is($d->{item_count}, 0, 'no items');
    is($d->{total_cents}, 0, 'total 0');
}

# 항목 추가
my ($i1, $i2);
{
    my $r = _req('POST', "/orders/$oid/items", _j({ sku => 'A', qty => 1, price_cents => 250 }));
    is($r->{code}, '201', 'item1 201');
    $i1 = _json($r)->{id};
    $r = _req('POST', "/orders/$oid/items", _j({ sku => 'B', qty => 2, price_cents => 100 }));
    is($r->{code}, '201', 'item2 201');
    $i2 = _json($r)->{id};
    isnt($i1, $i2, 'distinct item ids');
}

# 목록/합계
is(_json(_req('GET', "/orders/$oid/items"))->{count}, 2, 'two items');
is(_json(_req('GET', "/orders/$oid"))->{total_cents}, 450, 'total 250+200');

# 항목 삭제
is(_req('DELETE', "/orders/$oid/items/$i1")->{code}, '204', 'delete item 204');
is(_json(_req('GET', "/orders/$oid/items"))->{count}, 1, 'one item left');
is(_json(_req('GET', "/orders/$oid"))->{total_cents}, 200, 'total after delete');
is(_req('DELETE', "/orders/$oid/items/999")->{code}, '404', 'missing item 404');

# 제출
{
    my $r = _req('POST', "/orders/$oid/submit");
    is($r->{code}, '200', 'submit 200');
    is(_json($r)->{status}, 'submitted', 'submitted');
}

# 제출 후 변경 불가
is(_req('POST', "/orders/$oid/items", _j({ sku => 'C', qty => 1, price_cents => 1 }))->{code}, '409', 'add to submitted 409');
is(_req('DELETE', "/orders/$oid/items/$i2")->{code}, '409', 'delete from submitted 409');
is(_req('POST', "/orders/$oid/submit")->{code}, '409', 'resubmit 409');

# 빈 주문 제출 -> 422
{
    my $oid2 = _json(_req('POST', '/orders', _j({ customer => 'bob' })))->{id};
    my $r = _req('POST', "/orders/$oid2/submit");
    is($r->{code}, '422', 'empty submit 422');
    is(_json($r)->{code}, 'empty_order', 'empty_order code');
}

# 없는 주문
is(_req('GET', '/orders/999')->{code}, '404', 'unknown order 404');
is(_req('POST', '/orders/999/items', _j({ sku => 'x', qty => 1, price_cents => 1 }))->{code}, '404', 'items of unknown 404');

# 검증
is(_req('POST', '/orders', '{}')->{code}, '400', 'customer required 400');
is(_req('POST', "/orders/$oid/items", _j({ qty => 1, price_cents => 1 }))->{code}, '409', 'submitted check first (409)');
{
    my $oid3 = _json(_req('POST', '/orders', _j({ customer => 'c' })))->{id};
    is(_req('POST', "/orders/$oid3/items", _j({ qty => 1, price_cents => 1 }))->{code}, '400', 'sku required 400');
    is(_req('POST', "/orders/$oid3/items", _j({ sku => 'x', qty => 0, price_cents => 1 }))->{code}, '400', 'qty 0 400');
    is(_req('POST', "/orders/$oid3/items", _j({ sku => 'x', qty => 1, price_cents => -5 }))->{code}, '400', 'negative price 400');
}

done_testing();
