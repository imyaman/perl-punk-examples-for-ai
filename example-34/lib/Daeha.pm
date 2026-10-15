package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 데이터셋 ----
my @ITEMS = map { { id => $_, name => "item-$_" } } 1 .. 57;

# ---- 페이지네이션 + Link 헤더 ----
get '/items' => sub {
    my ($c) = @_;

    my $per  = int($c->param('per_page') // 10) || 10;
    my $page = int($c->param('page')     // 1)  || 1;
    $per  = 1   if $per < 1;
    $per  = 100 if $per > 100;

    my $total = scalar @ITEMS;
    my $pages = int(($total + $per - 1) / $per) || 1;
    $page = 1     if $page < 1;
    $page = $pages if $page > $pages;

    my $start = ($page - 1) * $per;
    my $end   = $start + $per - 1;
    $end = $#ITEMS if $end > $#ITEMS;
    my @slice = ($start <= $#ITEMS) ? @ITEMS[$start .. $end] : ();

    my $link = sub {
        my ($p, $rel) = @_;
        qq{</items?per_page=$per&page=$p>; rel="$rel"};
    };
    my @links = ($link->(1, 'first'));
    push @links, $link->($page - 1, 'prev') if $page > 1;
    push @links, $link->($page + 1, 'next') if $page < $pages;
    push @links, $link->($pages, 'last');
    $c->header('Link' => join(', ', @links));

    return {
        data => \@slice,
        meta => { page => $page, per_page => $per, total => $total, pages => $pages },
    };
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 34: 페이지네이션 + Link 헤더)

=head1 SYNOPSIS

GET /items?page=1&per_page=10   페이지 조회 + RFC 5988 Link 헤더
GET /api/ping|healthz|readyz    헬스체크

=cut
