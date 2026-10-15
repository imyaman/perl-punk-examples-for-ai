package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

my $START = time;
my %COUNT;

hook before_dispatch => sub {
    my ($c) = @_;
    my $p = $c->req->path;
    return if $p eq '/metrics';
    $COUNT{ $c->req->method . ' ' . $p }++;
    return;
};

sub _esc { my $s = shift; $s =~ s/(["\\])/\\$1/g; return $s }

get '/metrics' => sub {
    my ($c) = @_;
    my $out = '';

    $out .= "# HELP daeha_requests_total Total HTTP requests handled\n";
    $out .= "# TYPE daeha_requests_total counter\n";
    for my $k (sort keys %COUNT) {
        my ($m, $p) = split / /, $k, 2;
        $out .= sprintf "daeha_requests_total{method=\"%s\",path=\"%s\"} %d\n",
                _esc($m), _esc($p), $COUNT{$k};
    }

    $out .= "# HELP daeha_uptime_seconds Seconds since process start\n";
    $out .= "# TYPE daeha_uptime_seconds gauge\n";
    $out .= 'daeha_uptime_seconds ' . (time - $START) . "\n";

    $c->header('Content-Type' => 'text/plain; version=0.0.4; charset=utf-8');
    return $c->text($out, 200);
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 60: /metrics 지표 노출)

=head1 SYNOPSIS

GET /metrics  Prometheus 텍스트 포맷으로 요청 수/업타임 노출

=cut
