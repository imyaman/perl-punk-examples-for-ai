package Daeha;

use Punk;
use JSON::PP;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- WebSocket: 에코 서버 ----
websocket '/ws/echo' => sub {
    my ($c, $ws) = @_;

    $ws->on(open => sub {
        my ($ws) = @_;
        $ws->send('welcome');
    });

    $ws->on(message => sub {
        my ($ws, $text) = @_;
        $ws->send("echo:$text");
    });

    $ws->on(close => sub {
        my ($ws, $code, $reason) = @_;
        # 연결 종료 시 정리
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 28: WebSocket 에코)

=head1 SYNOPSIS

WS  /ws/echo        연결 시 welcome, 수신 메시지는 echo:<text> 로 응답
GET /api/ping|healthz|readyz  헬스체크

=cut
