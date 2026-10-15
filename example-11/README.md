# Example 11 - 훅: `before_dispatch` / `after_dispatch` (Punk + Perl)

라우팅 **이후, 핸들러 이전**과 **응답 확정 이후**에 공통 코드를 끼워 넣는 훅을
시연하는 예제입니다. 요청마다 request id 를 부여하고, 모든 응답 헤더에 실어 보냅니다.

- `hook before_dispatch` — 라우팅 뒤·가드 앞에서 실행 (여기서는 request id 부여)
- `hook after_dispatch` — 확정된 PSGI 응답 `[status, headers, body]` 를 받아 수정 가능

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/whoami     | 부여된 request id 확인 |

모든 응답에 `X-Request-Id` 헤더가 붙습니다.

## 동작 방식 (왜 이렇게 될까)

### 훅은 파이프라인의 고정된 지점

Punk의 요청 처리는 대략 이 순서입니다.

```
middleware → 라우팅 → before_dispatch → 가드 → 핸들러 → after_dispatch
```

- `before_dispatch` 는 **라우팅과 가드 사이**에서 돕니다. 그래서 어떤 라우트로
  갔는지, 어떤 파라미터인지 알고 있으면서도 핸들러 코드보다 먼저 공통 작업을 할 수
  있습니다. reference 를 반환하면 요청을 거기서 끊습니다(가드처럼 동작).
- `after_dispatch` 는 **완성된 PSGI 트리플릿**을 받아 헤더를 더하거나 응답을
  바꿔치기할 수 있습니다.

### 요청 스코프 값 전달은 `$c->stash`

`before_dispatch` 에서 만든 request id 를 `$c->stash->{rid}` 에 넣어, 뒤의 핸들러와
`after_dispatch` 가 같은 값을 읽습니다. 훅·가드·핸들러가 공유하는 유일한 요청
저장소가 `stash` 입니다.

### 전역 일괄 처리는 훅, 요청마다 만지는 것은 핸들러

request id 처럼 **모든 요청에 예외 없이** 적용할 로직은 핸들러마다 복붙하지 않고
훅에 둡니다. 핸들러는 자기 로직만 담당합니다.

### 훅 vs 미들웨어

- **훅**(이 예제): Punk 컨텍스트(`$c`)를 받는 프레임워크 내부 훅.
- **미들웨어**(예제 12): PSGI `$env` 를 받는 **가장 바깥** 래퍼. 컨텍스트보다 앞/뒤.

## Notes

- 클라이언트가 `X-Request-Id` 를 주면 그 값을, 없으면 생성한 값을 사용합니다.
