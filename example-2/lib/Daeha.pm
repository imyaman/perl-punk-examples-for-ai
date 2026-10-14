package Daeha;

use Punk;

# ---- 인메모리 아이템 저장소 (예제용, 프리시드) ----
my @ITEMS = (
    { id => 1, name => 'Alpha',    category => 'tool',  status => 'active',  price => 10 },
    { id => 2, name => 'Beta',     category => 'book',  status => 'active',  price => 20 },
    { id => 3, name => 'Gamma',    category => 'tool',  status => 'sold',    price => 15 },
    { id => 4, name => 'Delta',    category => 'book',  status => 'active',  price => 25 },
    { id => 5, name => 'Epsilon',  category => 'tool',  status => 'active',  price => 30 },
    { id => 6, name => 'Zeta',     category => 'other', status => 'sold',    price => 5  },
    { id => 7, name => 'Eta',      category => 'book',  status => 'active',  price => 12 },
    { id => 8, name => 'Theta',    category => 'tool',  status => 'sold',    price => 18 },
);

my %BY_ID = map { $_->{id} => $_ } @ITEMS;

sub _now {
    my (@t) = localtime(time());
    $t[4] += 1;
    $t[3] += 1;
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d", $t[5] + 1900, @t[4, 3, 2, 1, 0]);
}

# ---- 헬프 (기준선 유지) ----
get '/api/ping' => sub {
    my ($c) = @_;
    $c->json({ ping => 'pong' });
};

get '/api/healthz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ok' });
};

get '/api/readyz' => sub {
    my ($c) = @_;
    $c->json({ status => 'ready' });
};

# ---- 상세: 경로 파라미터 :id ----
get '/api/items/:id' => sub {
    my ($c) = @_;
    my $id = $c->param('id');
    unless (defined $id && $id =~ /^\d+$/) {
        return $c->json({ error => 'invalid id' }, 400);
    }
    my $item = $BY_ID{$id};
    unless ($item) {
        return $c->json({ error => 'item not found' }, 404);
    }
    $c->json($item);
};

# ---- 목록: 쿼리 파라미터 필터링 + 페이지네이션 ----
get '/api/items' => sub {
    my ($c) = @_;

    # 쿼리 파라미터 (명시적으로 req->query 로 읽음)
    my $q = $c->req->query;

    my $category = $q->{category} // '';
    my $status   = $q->{status}   // '';
    my $search   = $q->{search}   // '';

    # 페이지네이션 파라미터 + 기본값 + 상한
    my $page = _parse_page($q->{page}) // 1;
    my $per_page = _parse_per_page($q->{per_page}) // 20;

    # 필터 적용
    my @filtered = grep {
        (!length($category) || lc($_->{category}) eq lc($category)) &&
        (!length($status)   || lc($_->{status})   eq lc($status))   &&
        (!length($search)   || $_->{name} =~ /\Q$search\E/i)
    } @ITEMS;

    my $total = scalar @filtered;

    # 페이지 계산
    my $total_pages = $total ? int(($total + $per_page - 1) / $per_page) : 0;
    $page = 1 if $page < 1;
    $page = $total_pages if $total_pages && $page > $total_pages;

    my @page_items;
    if (@filtered) {
        my $start = ($page - 1) * $per_page;
        my $end = $start + $per_page - 1;
        my $max_idx = $#filtered;
        if ($start <= $max_idx) {
            my $slice_end = $end < $max_idx ? $end : $max_idx;
            @page_items = @filtered[$start .. $slice_end];
        }
    }

    $c->json({
        items => \@page_items,
        pagination => {
            page       => $page,
            per_page   => $per_page,
            total      => $total,
            total_pages => $total_pages,
        },
    });
};

sub _parse_page {
    my ($v) = @_;
    return unless defined $v && $v =~ /^\d+$/;
    return $v + 0;
}

sub _parse_per_page {
    my ($v) = @_;
    return unless defined $v && $v =~ /^\d+$/;
    my $n = $v + 0;
    $n = 1 if $n < 1;
    $n = 100 if $n > 100;
    return $n;
}

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 2: 쿼리/경로 파라미터 + 필터링 + 페이지네이션)

=head1 SYNOPSIS

GET /api/items                목록 (필터, 페이지네이션)
GET /api/items?category=tool  필터
GET /api/items?page=2&per_page=3  페이지네이션
GET /api/items?search=eta     검색
GET /api/items/:id            상세
GET /api/ping                 ping
GET /api/healthz              liveness
GET /api/readyz               readiness

=cut
