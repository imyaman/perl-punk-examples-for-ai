package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- SSE: 카운터를 3번 보내고 스트림을 닫는다 ----
sse '/events' => sub {
    my ($c, $stream) = @_;
    my $n = 0;
    my $tick;
    $tick = sub {
        return unless $stream->is_open;
        $n++;
        $stream->id($n)->send({ seq => $n, kind => 'counter' });
        if ($n >= 3) {
            $stream->close;
            return;
        }
        $c->timer(0.2)->on_done($tick);
    };
    $tick->();
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 27: Server-Sent Events)

=head1 SYNOPSIS

GET /events       text/event-stream, 카운터 3개 후 종료
GET /api/ping|healthz|readyz  헬스체크

=cut
