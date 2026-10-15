package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- URL 단축 (가장 단순 버전) ----
my %SHORT_TO_URL;
my %URL_TO_SHORT;
my $SEQ = 0;

sub _shorten {
    $SEQ++;
    return 's' . $SEQ;
}

get '/shorten' => sub {
    my ($c) = @_;
    my $url = $c->param('url');
    unless (defined $url && $url =~ m{^https?://}) {
        $c->header('Content-Type' => 'application/problem+json');
        return $c->json({
            type   => 'about:blank',
            title  => 'Bad Request',
            status => 400,
            detail => 'url must be http(s)://...',
        }, 400);
    }

    # 이미 생성한 적 있으면 재사용
    if (exists $URL_TO_SHORT{$url}) {
        my $code = $URL_TO_SHORT{$url};
        return $c->json({ short => "/$code", url => $url });
    }

    my $code = _shorten();
    $SHORT_TO_URL{$code} = $url;
    $URL_TO_SHORT{$url}  = $code;
    return $c->json({ short => "/$code", url => $url });
};

get '/:code' => sub {
    my ($c) = @_;
    my $code = $c->param('code');
    if (exists $SHORT_TO_URL{$code}) {
        return $c->redirect($SHORT_TO_URL{$code}, 302);
    }
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Not Found',
        status => 404,
        detail => 'short code not found',
        instance => "/$code",
    }, 404);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 44: URL 단축)

=head1 SYNOPSIS

GET /shorten?url=http://...  짧은 코드 생성
GET /:code                   원본 URL 로 302 리다이렉트

=cut
