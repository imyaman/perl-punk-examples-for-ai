package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 간단한 API 키 체크 ----
my %VALID_KEYS = (
    'demo-key' => 1,
    'test-key' => 1,
);

sub _forbidden {
    my ($c, $msg) = @_;
    $c->header('Content-Type' => 'application/problem+json');
    return $c->json({
        type   => 'about:blank',
        title  => 'Forbidden',
        status => 403,
        detail => $msg,
    }, 403);
}

# ---- 보호 구역 ----
get '/api/protected/data' => sub {
    my ($c) = @_;
    my $key = $c->req->header('x-api-key') // $c->param('api_key');
    unless (defined $key && $VALID_KEYS{$key}) {
        return _forbidden($c, 'invalid or missing api key');
    }
    $c->json({ data => [ { id => 1, name => 'secret' } ] });
};

# ---- 공개 ----
get '/api/public/info' => sub {
    $_[0]->json({ public => 1 });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 41: API Key 인증)

=head1 SYNOPSIS

GET /api/public/info           공개
GET /api/protected/data        보호(x-api-key 헤더 또는 api_key 쿼리)
                              유효키: demo-key, test-key

=cut
