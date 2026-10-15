# Example 22 - `ua` 로 외부 HTTP 호출 (Punk + Perl)

핸들러에서 **외부 API 를 호출**하는 예제입니다. `$c->ua` 는 Fetch 유저에이전트로,
연결 재사용(keep-alive)을 워커 단위로 공유합니다.

- `ua timeout => 5;` — 아웃바운드 에이전트 설정
- `$c->ua->get($url)->get` — 블로킹 호출, 응답 객체 반환
- 응답: `->status`, `->header($name)`, `->json`, `->content`

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/upstream   | `127.0.0.1:3029` 로 아웃바운드 GET 후 결과 반환 |

## 동작 방식 (왜 이렇게 될까)

### 에이전트는 요청마다가 아니라 워커마다 하나

`$c->ua` 는 Fetch 객체입니다. Fetch 는 keep-alive 연결 풀과 DNS 상태를 소유하므로,
요청마다 새로 만들면 매번 TCP/TLS 핸드셰이크를 다시 치릅니다. 그래서 Punk 는
**워커당 하나**를 첫 사용 시점에 만들고 모든 요청이 공유합니다. `to_app` 시점에는
아무것도 만들지 않습니다 — 서버가 fork 하기 전에 에이전트를 만들면 모든 워커가 한
세트의 소켓을 공유하게 되기 때문입니다.

### 블로킹과 비동기

- **블로킹**: `->get` 은 결과가 올 때까지 기다립니다("blocking, wherever you are").
  테스트/스크립트(이벤트 루프 밖)에서는 Fetch 자체 루프로 돕니다.
- **비동기**: `->get($url)->then(sub {...})` 로 future 를 반환하면, 워커가 그 요청을
  파킹하고 다른 요청을 처리합니다. 여러 업스트림을 동시에(`Fetch::Future->needs_all`)
  호출할 때 씁니다.

이 예제는 업스트림이 별도 프로세스라 데드락 없이 블로킹 형태로 단순하게 보여줍니다.

### 응답은 Fetch 의 것

Punk 가 감싸지 않으므로 응답 API 는 전부 Fetch 의 것입니다. `status`(숫자),
`header`(대소문자 무관), `content`(바이트), `json`(디코드) 등을 그대로 씁니다.
HTTP/2·리다이렉트 추적·스트리밍도 Fetch 문서 그대로 가능합니다.

### 여러 업스트림은 이름으로

`ua partner => { timeout => 2 }` 처럼 이름별 에이전트를 만들고
`$c->ua('partner')` 로 부를 수 있습니다. 업스트림마다 타임아웃·기본 헤더·쿠키
정책이 다를 때 유용합니다.

## Notes

- 테스트는 자식 프로세스로 가짜 업스트림(3029)을 띄워 실제 아웃바운드 호출을 검증합니다.
- 업스트림 실패 시 `502` 로 감싸 반환합니다(데모).
