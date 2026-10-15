# Example 29 - WebSocket 룸 브로드캐스트 (Punk + Perl)

여러 클라이언트를 **한 룸에 모아** 한 사람의 메시지를 전원에게 뿌리는 예제입니다.

- `Punk::WebSocket::Room->named('lobby')` — 이름별 룸
- `join` / `leave` / `broadcast($text, $except?)`
- `count` / `clients` / `close_all`

## Routes

| Type | Path        | Description |
|------|-------------|-------------|
| GET  | /api/ping   | ping/pong |
| GET  | /api/healthz| k8s liveness |
| GET  | /api/readyz | k8s readiness |
| WS   | /ws/chat    | 입장 시 `joined:<n>`, 메시지는 보낸 사람 제외 전원에게 |

## 동작 방식 (왜 이렇게 될까)

### 룸은 이름으로 식별하는 레지스트리

`Room->named('lobby')` 는 같은 이름에 대해 동일한 룸을 돌려줍니다. 이 메모리 안
맵을 이용해 "연결 집합"을 관리합니다. 클라이언트가 A·B 순서로 들어오면 각각
`joined:1`, `joined:2` 를 받습니다.

### 입장/퇴장은 연결 수명에 붙인다

- `open` → `$room->join($ws)`
- `close` → `$room->leave($ws)`

이렇게 하면 연결이 끊기면 자동으로 룸에서 빠집니다. 죽은 연결이 `broadcast` 대상에
남지 않으므로 메모리 누수도 막습니다.

### `broadcast($text, $except)` — 보낸 사람 제외

두 번째 인자에 보낸 클라이언트를 넘기면 그 사람은 제외합니다. 채팅의 기본 규칙이
자연스럽게 됩니다. 생략하면 전원에게(자기 포함) 뿌립니다.

### 룸과 스코프·가드

`websocket` 라우트는 GET 으로 라우팅되므로, 같은 스코프의 가드로 입장 전에 거부할
수 있습니다. 룸 입장 권한을 통제할 자리가 보호 구역입니다.

## Notes

- 테스트는 두 WS 클라이언트를 연결해 상호 수신을 검증합니다.
- 룸 상태는 워커 메모리에 있습니다(재시작 시 초기화).
