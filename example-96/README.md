# Example 96 - 서킷 브레이커 (Punk + Perl)

하위 서비스가 죽었을 때 **무의미한 호출을 멈춰** 장애를 전파하지 않는 서킷 브레이커 예제입니다.

- `closed` → 정상
- 임계 실패(`3`) → `open`
- `open` 동안 호출은 `503` + `Retry-After` (하위 호출 자체를 안 함)
- 시간 경과 후 `half_open` 시험 호출
- 성공하면 `closed` 복귀, 실패하면 다시 `open`

## Routes

| Method | Path                | Description |
|--------|---------------------|-------------|
| GET    | /api/ping           | ping/pong |
| GET    | /api/fetch          | 하위 호출(차단 대상) |
| GET    | /circuit            | 회로 상태 |
| POST   | /downstream/mode    | 하위 상태 시뮬레이션 |

## 동작 방식 (왜 이렇게 될까)

### 상태 3가지

| 상태 | 의미 | 하위 호출 |
|------|------|-----------|
| `closed` | 정상 | 함 |
| `open` | 차단 | 안 함 (즉시 실패) |
| `half_open` | 시험 | 한 번만 |

### 왜 차단하나

하위가 죽었는데 계속 호출하면 **스레드/연결을 낭비**하고, 죽은 하위에 부하를 계속 줘
회복을 방해합니다. 회로를 열면 빠르게 실패(`fail fast`)합니다.

```perl
if ($state eq 'open' && $elapsed < $open_secs) {
    return $c->json({ error => 'circuit open' }, 503);
}
```

### 임계값에서 열린다

연속 실패가 `threshold`(3)에 도달하면 OPEN 으로 전환합니다.

```perl
$failures++;
$state = 'open', $opened_at = _now() if $failures >= $threshold;
```

### half-open 시험

차단 시간이 지나면 **한 번만** 시험 호출을 허용합니다. 성공하면 `closed`(정상 복귀),
실패하면 곧바로 다시 `open`(여전히 문제).

### `503` + `Retry-After`

차단 중에는 `503 Service Unavailable` 과 함께 **언제쯤 다시** 시도할지 알려줍니다.

### `502` 와 `503` 의 구분

- `502 Bad Gateway`: 하위가 **응답했지만 실패**
- `503 Service Unavailable`: 회로가 **열려 시도조차 안 함**

## Notes

- 실전에서는 상태를 프로세스 밖(Redis 등)에 두어 인스턴스 간 공유합니다.
- 실패율 기반(예: 최근 1분 실패 50%)이나 느린 호출 타임아웃과 조합합니다.
- 테스트는 closed→open→차단→half-open→복구 전 과정을 검증합니다.
