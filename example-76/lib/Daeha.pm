package Daeha;

use Punk;
use JSON::PP;
use Digest::SHA qw(sha256_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my %BLOBS;   # hex digest => { id, size, content_type, data }

post '/blobs' => sub {
    my ($c) = @_;
    my $data = $c->req->body // '';
    return $c->json({ error => 'empty body' }, 400) unless length $data;

    my $id = sha256_hex($data);
    my $ct = $c->req->header('content-type') // 'application/octet-stream';
    $ct =~ s/;.*//;

    my $existed = exists $BLOBS{$id};
    $BLOBS{$id} //= { id => $id, size => length($data), content_type => $ct, data => $data };

    $c->header('Location' => "/blobs/$id");
    $c->header('ETag' => "\"$id\"");
    return $c->json({
        id => $id, size => $BLOBS{$id}{size},
        content_type => $BLOBS{$id}{content_type}, deduplicated => $existed ? 1 : 0,
    }, $existed ? 200 : 201);
};

get '/blobs/:id/meta' => sub {
    my ($c) = @_;
    my $b = $BLOBS{$c->param('id')};
    return $c->json({ error => 'not found' }, 404) unless $b;
    return $c->json({ id => $b->{id}, size => $b->{size}, content_type => $b->{content_type} });
};

get '/blobs/:id' => sub {
    my ($c) = @_;
    my $b = $BLOBS{$c->param('id')};
    return $c->json({ error => 'not found' }, 404) unless $b;

    # 조건부 GET
    my $inm = $c->req->header('if-none-match');
    if (defined $inm && $inm eq "\"$b->{id}\"") {
        $c->header('ETag' => "\"$b->{id}\"");
        return $c->text('', 304);
    }

    $c->header('Content-Type' => $b->{content_type});
    $c->header('ETag' => "\"$b->{id}\"");
    return $c->text($b->{data}, 200);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 76: 콘텐츠 주소 저장소)

=head1 SYNOPSIS

POST /blobs        본문의 SHA-256 을 id 로 저장(중복 제거)
GET  /blobs/:id    내용 반환
GET  /blobs/:id/meta 메타데이터

=cut
