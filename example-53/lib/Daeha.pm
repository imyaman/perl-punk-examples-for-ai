package Daeha;

use Punk;
use JSON::PP;
use Digest::MD5 qw(md5_hex);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $REV  = 1;
my $TEXT = 'version-1';

sub _etag { '"' . md5_hex("$REV:$TEXT") . '"' }

sub _problem {
    my ($c, $status, $title, $detail) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type => 'about:blank', title => $title, status => $status, detail => $detail,
    }, $status);
}

get '/doc' => sub {
    my ($c) = @_;
    $c->header('ETag' => _etag());
    return $c->json({ rev => $REV, text => $TEXT });
};

put '/doc' => sub {
    my ($c) = @_;
    my $etag = _etag();
    my $im = $c->req->header('if-match');

    return _problem($c, 428, 'Precondition Required', 'If-Match header is required')
        unless defined $im;

    if ($im ne '*' && $im ne $etag) {
        return _problem($c, 412, 'Precondition Failed', 'If-Match does not match current ETag');
    }

    my $body = $c->req->json // {};
    $TEXT = $body->{text} if exists $body->{text};
    $REV++;

    $c->header('ETag' => _etag());
    return $c->json({ rev => $REV, text => $TEXT });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 53: 낙관적 동시성 If-Match)

=head1 SYNOPSIS

GET /doc  200 + ETag
PUT /doc  If-Match 필수. 불일치시 412, 누락시 428

=cut
