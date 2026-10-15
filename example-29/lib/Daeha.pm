package Daeha;

use Punk;
use JSON::PP;
use Punk::WebSocket::Room;

# ---- 헬스체크 (기준선) ----
get '/api/ping'    => sub { $_[0]->json({ ping => 'pong' }) };
get '/api/healthz' => sub { $_[0]->json({ status => 'ok' }) };
get '/api/readyz'  => sub { $_[0]->json({ status => 'ready' }) };

# ---- WebSocket: 채팅방 브로드캐스트 ----
websocket '/ws/chat' => sub {
    my ($c, $ws) = @_;
    my $room = Punk::WebSocket::Room->named('lobby');

    $ws->on(open => sub {
        my ($ws) = @_;
        $room->join($ws);
        $ws->send('joined:' . $room->count);
    });

    $ws->on(message => sub {
        my ($ws, $text) = @_;
        $room->broadcast($text, $ws);    # 보낸 사람 제외 전원에게
    });

    $ws->on(close => sub {
        my ($ws) = @_;
        $room->leave($ws);
    });
};

1;

__END__

=head1 NAME

Daeha - a Punk HTTP API (예제 29: WebSocket 룸 브로드캐스트)

=head1 SYNOPSIS

WS  /ws/chat     입장 시 joined:<n>, 메시지는 보낸 사람 제외 전원에게
GET /api/ping|healthz|readyz  헬스체크

=cut
