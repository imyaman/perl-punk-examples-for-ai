package Daeha;

use Punk;
use JSON::PP;
use POSIX qw(strftime);

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

sub _http_date { strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime($_[0])) }

my %POLICY = (
    'public'   => 'public, max-age=3600',
    'private'  => 'private, no-store',
    'no-cache' => 'no-cache, max-age=0, must-revalidate',
    'swr'      => 'public, max-age=60, stale-while-revalidate=30',
    'immutable'=> 'public, max-age=31536000, immutable',
);

get '/cache/:kind' => sub {
    my ($c) = @_;
    my $kind = $c->param('kind');
    my $cc = $POLICY{$kind};
    return $c->json({ error => 'unknown policy' }, 404) unless defined $cc;

    $c->header('Cache-Control' => $cc);

    # max-age 가 있으면 Expires 도 함께 (구형 캐시 호환)
    if ($cc =~ /max-age=(\d+)/) {
        $c->header('Expires' => _http_date(time() + $1));
    }

    return $c->json({ policy => $kind, cache_control => $cc });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 70: Cache-Control 정책)

=head1 SYNOPSIS

GET /cache/:kind  kind 에 따라 Cache-Control/Expires 를 다르게 설정

=cut
