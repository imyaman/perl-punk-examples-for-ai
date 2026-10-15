# Example 97 - 롱폴링 (Long Polling) (Punk + Perl)

새 이벤트가 생길 때까지 **연결을 잡고 기다렸다가** 응답하는 롱폴링 예제입니다. Punk 의
비동기 future(`$c->promise`, `$c->timer`)를 사용합니다.

- `POST /events` → 이벤트 적재
- `GET /wait?since=&timeout_ms=` → `since` 이후 이벤트가 있으면 즉시, 없으면 timeout 후 `204`
- 타임아웃 기본 1000ms, 1..30000ms

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| POST   | /events      | 이벤트 적재 |
| GET    | /events      | 전체 목록 |
| GET    | /wait        | 롱폴링 대기 |

## 동작 방식 (왜 이렇게 될까)

### 즉시 반환 vs 대기

`since` 이후 이벤트가 이미 있으면 **바로** 돌려줍니다. 없을 때만 기다립니다.

```perl
if (my $ev = _next($since)) { return $c->json({ event => $ev, waited => 0 }) }
```

### 기다리기는 future 로

Punk 는 처리기가 **future 를 반환하면** 완료를 기다립니다. `$c->promise` 로 pending
future 를 만들고, `$c->timer(...)` 가 만료되면 값을 채웁니다.

```perl
my $p = $c->promise;
$c->timer($timeout_ms / 1000)->on_done(sub {
    my $ev = _next($since);
    $p->done($ev ? $c->json({ event => $ev }) : $c->text('', 204));
});
return $p;
```

### 반환 시점에도 다시 확인

타이머가 만료되는 순간 **다시 조회**합니다. 대기 중 들어온 이벤트를 놓치지 않기
위함입니다.

### `204 No Content`

시간이 다 됐는데 새 게 없으면 본문 없이 `204` 를 줍니다. 클라이언트는 곧바로 다시
`/wait` 을 호출합니다.

### 폴링 vs 롱폴링 vs SSE

| 방식 | 지연 | 연결 | 비고 |
|------|------|------|------|
| 짧은 폴링 | 큼 | 짧음 | 단순, 트래픽 많음 |
| 롱폴링 | 낮음 | 길게 유지 | 여기서 사용 |
| SSE | 낮음 | 단방향 스트림 | 서버 push |

### timeout 을 두는 이유

무한정 대기하면 프록시/로드밸런서가 연결을 끊거나 자원이 묶입니다. 상한을 두고 `204`
로 **재시도 신호**를 줍니다.

## Notes

- 여기서는 대기 중 새 이벤트가 와도 즉시 깨어나진 않습니다(타임아웃 때 재확인). 즉시
  깨우려면 대기자 목록/조건변수로 알림해야 합니다.
- 실전 스트리밍은 SSE(`sse` 라우트)나 WebSocket 이 적합합니다.
- 테스트는 즉시 반환/타임아웃 204/신규 반환/검증을 확인합니다.
