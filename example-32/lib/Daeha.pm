package Daeha;

use Punk;
use JSON::PP;
use Digest::MD5 qw(md5_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 리소스 상태(프로세스 메모리) ----
my $REV  = 1;
my $TEXT = 'hello';

sub _etag { '"' . md5_hex("$REV:$TEXT") . '"' }

# ---- 조건부 GET: If-None-Match -> 304 ----
get '/resource' => sub {
    my ($c) = @_;
    my $etag = _etag();
    $c->header('ETag' => $etag);

    my $inm = $c->req->header('if-none-match');
    if (defined $inm && $inm eq $etag) {
        return $c->text('', 304);        # 본문 없는 304
    }
    return { rev => $REV, text => $TEXT };
};

# ---- 갱신: 새 ETag 발급 ----
put '/resource' => sub {
    my ($c) = @_;
    my $body = $c->req->json // {};
    if (exists $body->{text}) {
        $TEXT = $body->{text};
        $REV++;
    }
    my $etag = _etag();
    $c->header('ETag' => $etag);
    return { rev => $REV, text => $TEXT, etag => $etag };
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 32: ETag / 조건부 GET 304)

=head1 SYNOPSIS

GET /resource  200 + ETag, If-None-Match 일치 시 304
PUT /resource  본문 갱신 후 새 ETag
GET /api/ping|healthz|readyz  헬스체크

=cut
