# Example 28 - WebSocket 에코 (Punk + Perl)

WebSocket 연결을 열고 메시지에 반응하는 예제입니다. 연결 시 `welcome` 을 보내고,
수신한 텍스트를 `echo:<text>` 로 돌려줍니다.

- `websocket '/ws/echo' => $handler` — GET 처럼 라우팅되는 업그레이드 라우트
- 핸들러는 `($c, $ws)` 를 받음
- 이벤트 와이어링: `$ws->on(open|message|close => sub {...})`

## Routes

| Type | Path        | Description |
|------|-------------|-------------|
| GET  | /api/ping   | ping/pong |
| GET  | /api/healthz| k8s liveness |
| GET  | /api/readyz | k8s readiness |
| WS   | /ws/echo    | 연결 시 `welcome`, 수신 시 `echo:<text>` |

## 동작 방식 (왜 이렇게 될까)

### 업그레이드는 GET 이다

WebSocket 핸드셰이크는 **GET + Upgrade** 요청입니다. 그래서 `websocket` 라우트는
GET 처럼 라우팅되고, 같은 스코프·가드 아래에 놓입니다. 즉 **가드가 업그레이드 전에
평범한 HTTP 응답으로 거부**할 수 있습니다(인증 실패 등).

### 핸들러는 이벤트를 걸고 반환한다

핸들러는 소켓을 직접 루프에 넘기지 않습니다. `$ws->on(...)` 으로 원하는 이벤트만
배선하고 **반환**하면, 이후 연결은 서버 이벤트 루프가 살립니다. 연결마다 워커를
붙잡지 않습니다.

```
$ws->on(open    => sub { $_[0]->send('welcome') });
$ws->on(message => sub { my ($ws, $text) = @_; $ws->send("echo:$text") });
```

### 서버 요구사항

- Hyperman 0.11+ 는 소켓을 앱에 넘기는 `detach` 를 제공 → 워커 미점유 스트리밍.
- 그 외 PSGI 서버는 `blocking => 1` 로 핸들러 안에서 `psgix.io` 스트리밍(워커 점유).
- 둘 다 없으면 `to_app` 이 croak 합니다(서비스 못 하는 라우트로 시작하지 않게).

### 브로드캐스트

여러 클라이언트에 뿌리려면 `Punk::WebSocket::Room->named('lobby')` 에 `join` 후
`broadcast` 합니다. 여기서는 단일 연결 에코만 다룹니다.

## Notes

- 테스트는 `Fetch::WebSocket` 클라이언트로 핸드셰이크 → open 메시지 → 에코 2회를 검증합니다.
