#!/usr/bin/perl
use Test::More;

use_ok('Daeha');

my $app = Daeha->to_app;
ok($app, "the application compiles to a PSGI coderef");

sub _get {
    my ($app, $path, $query) = @_;
    my $env = {
        REQUEST_METHOD => 'GET',
        PATH_INFO      => $path,
        QUERY_STRING   => $query // '',
        SERVER_NAME    => 'localhost',
    };
    return $app->($env);
}

sub _decode_json {
    my ($res) = @_;
    my $raw = join("", @{$res->[2]});
    return eval {
        require JSON::PP;
        JSON::PP->new->decode($raw);
    } || {};
}

# ---- 헬프 (기준선) ----
{
    my $res = _get($app, '/api/ping');
    is($res->[0], 200, "GET /api/ping is 200");
    my $d = _decode_json($res);
    is($d->{ping}, 'pong', "...ping pong");
}

# ---- 전체 목록 (기본 페이지네이션) ----
{
    my $res = _get($app, '/api/items');
    is($res->[0], 200, "GET /api/items is 200");
    my $d = _decode_json($res);
    is($d->{pagination}{page}, 1, "...default page 1");
    is($d->{pagination}{per_page}, 20, "...default per_page 20");
    is($d->{pagination}{total}, 8, "...total 8");
    is(scalar @{ $d->{items} }, 8, "...returns all 8 items");
}

# ---- 카테고리 필터: tool ----
{
    my $res = _get($app, '/api/items', 'category=tool');
    my $d = _decode_json($res);
    is($d->{pagination}{total}, 4, "...tool total 4");
    is(scalar @{ $d->{items} }, 4, "...returns 4 tool items");
    ok(grep { $_->{category} eq 'tool' } @{ $d->{items} }, "...all are tool");
}

# ---- 상태 필터: sold ----
{
    my $res = _get($app, '/api/items', 'status=sold');
    my $d = _decode_json($res);
    is($d->{pagination}{total}, 3, "...sold total 3");
    ok(grep { $_->{status} eq 'sold' } @{ $d->{items} }, "...all are sold");
}

# ---- 검색: name 에 'et' 포함 ----
{
    my $res = _get($app, '/api/items', 'search=et');
    my $d = _decode_json($res);
    is($d->{pagination}{total}, 4, "...search et total 4");
    ok(grep { $_->{name} =~ /et/i } @{ $d->{items} }, "...all match et");
}

# ---- 복합 필터 ----
{
    my $res = _get($app, '/api/items', 'category=book&status=active');
    my $d = _decode_json($res);
    is($d->{pagination}{total}, 3, "...book+active total 3");
    ok(grep { $_->{category} eq 'book' && $_->{status} eq 'active' } @{ $d->{items} }, "...all match");
}

# ---- 페이지네이션 page=1, per_page=2 ----
{
    my $res = _get($app, '/api/items', 'page=1&per_page=2');
    my $d = _decode_json($res);
    is($d->{pagination}{page}, 1, "...page 1");
    is($d->{pagination}{per_page}, 2, "...per_page 2");
    is($d->{pagination}{total}, 8, "...total 8");
    is($d->{pagination}{total_pages}, 4, "...total_pages 4");
    is(scalar @{ $d->{items} }, 2, "...returns 2 items");
}

# ---- 페이지네이션 page=2, per_page=3 ----
{
    my $res = _get($app, '/api/items', 'page=2&per_page=3');
    my $d = _decode_json($res);
    is($d->{pagination}{page}, 2, "...page 2");
    is($d->{pagination}{per_page}, 3, "...per_page 3");
    is(scalar @{ $d->{items} }, 3, "...returns 3 items");
    # 1-based item order preserved
    is($d->{items}[0]{id}, 4, "...first item id 4");
    is($d->{items}[2]{id}, 6, "...third item id 6");
}

# ---- 페이지 초과: page=999 → 보정되어 마지막 페이지 ----
{
    my $res = _get($app, '/api/items', 'page=999&per_page=10');
    my $d = _decode_json($res);
    is($d->{pagination}{page}, 1, "...page corrected to 1 when per_page>=total");
    is(scalar @{ $d->{items} }, 8, "...returns all items");
}

# ---- per_page 상한 적용 (200 → 100) ----
{
    my $res = _get($app, '/api/items', 'per_page=200');
    my $d = _decode_json($res);
    is($d->{pagination}{per_page}, 100, "...per_page capped at 100");
    is(scalar @{ $d->{items} }, 8, "...returns all items");
}

# ---- 비정상 page -> 기본값 1 ----
{
    my $res = _get($app, '/api/items', 'page=-1&per_page=2');
    my $d = _decode_json($res);
    is($d->{pagination}{page}, 1, "...invalid page defaults to 1");
    is($d->{pagination}{per_page}, 2, "...per_page 2");
}

# ---- 상세: 존재하는 id ----
{
    my $res = _get($app, '/api/items/1');
    is($res->[0], 200, "GET /api/items/1 is 200");
    my $d = _decode_json($res);
    is($d->{id}, 1, "...id 1");
    is($d->{name}, 'Alpha', "...name Alpha");
}

# ---- 상세: 없는 id -> 404 ----
{
    my $res = _get($app, '/api/items/99999');
    is($res->[0], 404, "GET /api/items/99999 is 404");
    my $d = _decode_json($res);
    is($d->{error}, 'item not found', "...error message");
}

# ---- 상세: 비정형 id -> 400 ----
{
    my $res = _get($app, '/api/items/abc');
    is($res->[0], 400, "GET /api/items/abc is 400");
    my $d = _decode_json($res);
    is($d->{error}, 'invalid id', "...invalid id message");
}

# ---- 쿼리 파라미터가 경로 파라미터보다 우선하지 않음 확인 (경로캡처가 :id 제공) ----
# /api/items/5 존재, 쿼리 ?id=99 는 무시돼야 함 (경로캡처 우선)
{
    my $res = _get($app, '/api/items/5', 'id=99');
    my $d = _decode_json($res);
    is($d->{id}, 5, "...path capture id wins over query id");
}

done_testing();
