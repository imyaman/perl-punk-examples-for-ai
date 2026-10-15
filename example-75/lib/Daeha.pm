package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my @PRODUCTS = (
    { id => 1, name => 'Apple iPhone',  tags => ['phone', 'apple'] },
    { id => 2, name => 'Apple Watch',   tags => ['watch', 'apple'] },
    { id => 3, name => 'Samsung Galaxy', tags => ['phone', 'android'] },
    { id => 4, name => 'Google Pixel',  tags => ['phone', 'android'] },
    { id => 5, name => 'Anker Charger', tags => ['accessory'] },
    { id => 6, name => 'Apple Pencil',  tags => ['accessory', 'apple'] },
);

get '/search' => sub {
    my ($c) = @_;
    my $q = $c->param('q');
    return $c->json({ error => 'q required' }, 400)
        unless defined $q && length $q;

    my $needle = lc $q;
    my @hits;
    for my $p (@PRODUCTS) {
        my $score = 0;
        $score += 2 if index(lc($p->{name}), $needle) >= 0;
        $score += 1 if grep { index(lc($_), $needle) >= 0 } @{ $p->{tags} };
        next unless $score;
        push @hits, { %$p, score => $score };
    }
    @hits = sort { $b->{score} <=> $a->{score} || $a->{id} <=> $b->{id} } @hits;

    return $c->json({ query => $q, count => scalar @hits, items => \@hits });
};

get '/search/suggest' => sub {
    my ($c) = @_;
    my $prefix = $c->param('prefix');
    return $c->json({ error => 'prefix required' }, 400)
        unless defined $prefix && length $prefix;

    my $limit = int($c->param('limit') // 5) || 5;
    $limit = 1  if $limit < 1;
    $limit = 20 if $limit > 20;

    my $lp = lc $prefix;
    my @names;
    for my $p (sort { $a->{id} <=> $b->{id} } @PRODUCTS) {
        push @names, $p->{name} if index(lc($p->{name}), $lp) == 0;
        last if @names >= $limit;
    }
    return $c->json({ prefix => $prefix, suggestions => \@names });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 75: 검색 + 자동완성)

=head1 SYNOPSIS

GET /search?q=phone           이름/태그 부분 일치 + 점수
GET /search/suggest?prefix=ap 자동완성(prefix)

=cut
