package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 인메모리 "미디어" ----
my @IMAGES = (
    { id => 1, ext => 'jpg', data => 'FAKEJPEGDATA123' },
    { id => 2, ext => 'png', data => 'FAKEPNGGDATA456' },
);

# ---- 원시 바이트 (먼저 선언) ----
get '/images/:id/raw' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my ($img) = grep { $_->{id} == $id } @IMAGES;
    unless ($img) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Not Found',
            status => 404,
            detail => 'image not found',
            instance => "/images/$id/raw",
        }, 404);
    }
    my $ct = $img->{ext} eq 'png' ? 'image/png' : 'image/jpeg';
    $c->header('Content-Type' => $ct);
    $c->header('Content-Length' => length($img->{data}));
    $c->header('Cache-Control' => 'public, max-age=60');
    return $c->text($img->{data});
};

# ---- 메타데이터 ----
get '/images/:id' => sub {
    my ($c) = @_;
    my $id = int($c->param('id') // 0);
    my ($img) = grep { $_->{id} == $id } @IMAGES;
    unless ($img) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Not Found',
            status => 404,
            detail => 'image not found',
            instance => "/images/$id",
        }, 404);
    }
    return $c->json({ id => $img->{id}, ext => $img->{ext}, url => "/images/$img->{id}/raw" });
};

get '/images' => sub {
    my ($c) = @_;
    my @list = map { { id => $_->{id}, ext => $_->{ext}, url => "/images/$_->{id}/raw" } } @IMAGES;
    return $c->json({ items => \@list });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 46: 바이트 응답 / 원시 데이터)

=head1 SYNOPSIS

GET /images        이미지 목록
GET /images/:id    메타데이터
GET /images/:id/raw 원시 바이트 응답 (image/*)

=cut
