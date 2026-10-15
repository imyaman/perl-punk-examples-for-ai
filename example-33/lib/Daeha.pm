package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 리다이렉트 대상 ----
get '/target' => sub { $_[0]->json({ at => 'target' }) };

# ---- 상태별 리다이렉트 (기본값은 302) ----
for my $code (301, 302, 303, 307, 308) {
    get "/redirect/$code" => sub {
        my ($c) = @_;
        $c->redirect('/target', $code);
    };
}

get '/redirect/default' => sub {
    my ($c) = @_;
    $c->redirect('/target');
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 33: 리다이렉트 상태 코드)

=head1 SYNOPSIS

GET /redirect/301|302|303|307|308  해당 코드로 /target 이동
GET /redirect/default              302 로 이동
GET /target                        도착지
GET /api/ping|healthz|readyz       헬스체크

=cut
