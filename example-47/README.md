# Example 47 - 레이트 리밋 (고정 윈도우) (Punk + Perl)

클라이언트(IP)당 **고정 시간 창**에 요청 횟수를 제한하는 예제입니다. 초과 시
`429 Too Many Requests` 와 `Retry-After` 를 반환합니다.

- 창: 10초, 한도: 3회 (테스트가 빠르도록 짧게)
- 응답 헤더: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `X-RateLimit-Reset`
- 초과 시: `429` + `Retry-After` (RFC 7807 본문)

## Routes

| Method | Path       | Description |
|--------|------------|-------------|
| GET    | /api/ping  | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /limited   | IP당 10초 3회 제한 |

## 동작 방식 (왜 이렇게 될까)

### 고정 윈도우(Fixed Window) 알고리즘

각 클라이언트마다 `{count, reset}` 버킷을 둡니다. 요청이 오면:

1. 버킷이 없거나 `reset` 시각이 지났으면 → 새 창 시작(`reset = now + WINDOW`)
2. `count++`
3. `count > LIMIT` 이면 `429`

```perl
if (!$b || $now >= $b->{reset}) {
    $b = { count => 0, reset => $now + $WINDOW };
}
$b->{count}++;
```

### 클라이언트 식별

프록시 뒤에서는 `X-Forwarded-For` 를 우선 사용하고, 없으면 `REMOTE_ADDR` 로
폴백합니다. (실서비스에선 신뢰 가능한 프록시만 `X-Forwarded-For` 를 세팅하도록
해 두어야 위·변조를 막을 수 있습니다.)

### 헤더로 상태 전달

`X-RateLimit-Remaining` 으로 남은 횟수를 미리 알려 주면, 클라이언트가 429 를 맞기
전에 스스로 조절할 수 있습니다. `Retry-After` 는 언제 다시 시도하면 되는지(초)를
알려 줍니다.

### 고정 윈도우의 한계

창 경계에서 순간적으로 2배까지 허용될 수 있습니다(예: 창 끝과 다음 창 시작에 몰림).
이를 완화하려면 슬라이딩 윈도우나 토큰 버킷을 씁니다. 또한 여기서는 단일 프로세스
메모리라 다중 워커에서는 공유되지 않습니다.

## Notes

- 테스트는 3회 허용 → 4번째 429, `Retry-After`/`X-RateLimit-*` 헤더를 검증합니다.
