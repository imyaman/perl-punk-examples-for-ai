package Daeha;

use Punk;
use JSON::PP;

# ---- 아웃바운드 에이전트 설정 ----
ua timeout => 5;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- 업스트림(외부 API) 호출 ----
get '/api/upstream' => sub {
    my ($c) = @_;
    my $res = eval { $c->ua->get('http://127.0.0.1:3029/hello')->get };
    if (!$res) {
        my $err = $@ || 'unknown error';
        $err =~ s/\s+\z//;
        return $c->json({ error => 'upstream failed', detail => $err }, 502);
    }
    $c->json({
        status       => $res->status,
        content_type => $res->header('Content-Type'),
        body         => $res->json,
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 22: ua 로 외부 HTTP 호출)

=head1 SYNOPSIS

GET /api/upstream   127.0.0.1:3029 로 아웃바운드 GET
GET /api/ping|healthz|readyz  헬스체크

=cut
