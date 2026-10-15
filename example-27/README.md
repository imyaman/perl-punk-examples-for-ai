# Example 27 - Server-Sent Events (`sse`) (Punk + Perl)

`text/event-stream` 으로 **서버→클라이언트 단방향 푸시**를 하는 예제입니다.
브라우저 `EventSource` 가 스스로 재연결합니다. 여기서는 카운터 3개를 보내고
스트림을 닫습니다.

- `sse '/events' => $handler` — 소켓을 넘겨받는 스트리밍 라우트
- 핸들러는 `($c, $stream)` 를 받음
- `$stream->send(...)`, `->event($name,...)`, `->id($id)`, `->comment($text)`, `->close`

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /events         | SSE 카운터 3개 후 종료 |

## 응답 예

```
id: 1
data: {"seq":1,"kind":"counter"}

id: 2
data: {"seq":2,"kind":"counter"}
...
```

## 동작 방식 (왜 이렇게 될까)

### 핸들러가 소켓을 넘겨받는다

일반 핸들러는 응답을 반환하지만, `sse` 핸들러는 Punk 가 소켓을 넘긴 뒤
`($c, $stream)` 로 호출됩니다. 이후 이 핸들러가 스트림에 이벤트를 밀어 넣습니다.
연결마다 워커를 붙잡지 않고, 스트림은 워커의 이벤트 루프에서 삽니다.

### 전송 계층은 서버가 고른다

- Hyperman 워커: 소켓을 떼어내 루프에서 스트리밍(워커 미점유)
- `psgi.streaming` 서버: 표준 지연 응답 writer 사용
- `blocking => 1`: 핸들러 안에서 `psgix.io` 로 스트리밍(워커 1개 점유)

셋 다 없으면 501 을 돌려줍니다.

### 데이터 규약

`send($ref)` 는 JSON 으로 인코딩되고, `event($name,$data)` 는 `event:` 필드를,
`id($id)` 는 재접속 시 `Last-Event-ID` 로 되돌아올 식별자를 씁니다. `comment` 는
keep-alive 용(`:comment`)입니다. `heartbeat`(기본 15초)로 연결 유지를 자동 처리합니다.

### 재연결

브라우저는 끊기면 자동 재접속하며, 마지막 `id` 를 `Last-Event-ID` 헤더로 보냅니다.
핸들러에서 `$c->req->header('last-event-id')` 로 읽어 이어 보낼 수 있습니다.

## Notes

- 테스트는 `curl -sN` 으로 이벤트 3개와 `id:`/`data:` 규약을 검증합니다.
