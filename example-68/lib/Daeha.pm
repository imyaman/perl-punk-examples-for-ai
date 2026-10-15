package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @ITEMS = map { { id => $_, title => "item-$_" } } 1 .. 25;
my $TOTAL = scalar @ITEMS;

any '/things' => sub {
    my ($c) = @_;

    my $limit = int($c->param('limit') // 10) || 10;
    $limit = 1  if $limit < 1;
    $limit = 50 if $limit > 50;
    my $page = int($c->param('page') // 1) || 1;
    $page = 1 if $page < 1;

    my $start = ($page - 1) * $limit;
    my @slice;
    if ($start < $TOTAL) {
        my $end = $start + $limit - 1;
        $end = $TOTAL - 1 if $end > $TOTAL - 1;
        @slice = @ITEMS[$start .. $end];
    }

    my $pages = int(($TOTAL + $limit - 1) / $limit);
    $pages = 1 if $pages < 1;

    $c->header('X-Total-Count' => $TOTAL);
    $c->header('X-Page'        => $page);
    $c->header('X-Per-Page'    => $limit);

    my @links;
    push @links, "</things?limit=$limit&page=" . ($page - 1) . '>; rel="prev"' if $page > 1;
    push @links, "</things?limit=$limit&page=" . ($page + 1) . '>; rel="next"' if $page < $pages;
    push @links, "</things?limit=$limit&page=1>; rel=\"first\"";
    push @links, "</things?limit=$limit&page=$pages>; rel=\"last\"";
    $c->header('Link' => join(', ', @links));

    # HEAD 는 키워드가 없으므로 any 로 받아 분기한다
    if ($c->req->method eq 'HEAD') {
        return $c->text('', 200);
    }

    return $c->json({
        items    => \@slice,
        page     => $page,
        per_page => $limit,
        total    => $TOTAL,
        pages    => $pages,
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 68: HEAD + 페이지네이션 메타)

=head1 SYNOPSIS

GET /things   항목 + X-Total-Count + Link(rel=next..)
HEAD /things  동일 헤더, 본문 없음

=cut
