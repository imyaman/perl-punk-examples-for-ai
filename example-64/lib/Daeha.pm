package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $MAX_BYTES = 1024;

sub _too_large {
    my ($c, $len) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type => 'about:blank', title => 'Payload Too Large', status => 413,
        detail => "body exceeds $MAX_BYTES bytes",
    }, 413);
}

post '/submit' => sub {
    my ($c) = @_;

    # 1) Content-Length 로 선제 거절 (본문을 읽지 않아도 됨)
    my $cl = $c->req->header('content-length');
    if (defined $cl && $cl =~ /^\d+$/ && $cl > $MAX_BYTES) {
        return _too_large($c, $cl);
    }

    # 2) 실제 본문 길이로 재확인 (chunked 등 Content-Length 가 없을 수 있음)
    my $body = $c->req->body // '';
    if (length($body) > $MAX_BYTES) {
        return _too_large($c, length $body);
    }

    my $data = eval { JSON::PP->new->decode($body) };
    if ($@) {
        return $c->json({ error => 'malformed JSON' }, 400);
    }

    return $c->json({ received => 1, bytes => length($body), data => $data });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 64: 요청 본문 크기 제한)

=head1 SYNOPSIS

POST /submit  $MAX_BYTES 초과 시 413

=cut
