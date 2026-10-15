# Example 86 - 분산 락 / 임대 + TTL (Punk + Perl)

여러 워커가 같은 자원을 동시에 건드리지 않도록 **이름 기반 락**을 잡고, TTL 로 자동
만료시키는 예제입니다. 락에는 **소유자 토큰**이 있어 남의 락을 함부로 풀 수 없습니다.

- `POST /locks/:name` → 획득(`201`) / 이미 점유면 `409`
- `GET /locks/:name` → 보유자
- `PUT /locks/:name/renew` → 토큰이 맞으면 TTL 연장
- `DELETE /locks/:name` → 토큰이 맞으면 해제(`204`)
- TTL 이 지나면 **자동 해제**

## Routes

| Method | Path                | Description |
|--------|---------------------|-------------|
| GET    | /api/ping           | ping/pong |
| GET    | /api/healthz        | k8s liveness |
| GET    | /api/readyz         | k8s readiness |
| POST   | /locks/:name        | 락 획득 (`owner`, `ttl`) |
| GET    | /locks/:name        | 보유자 조회 |
| PUT    | /locks/:name/renew  | 갱신 (`token`, `ttl`) |
| DELETE | /locks/:name        | 해제 (`token`) |
| GET    | /locks              | 전체 목록 |

## 동작 방식 (왜 이렇게 될까)

### 왜 TTL(임대)인가

락을 잡은 프로세스가 **죽으면 락이 영원히 남습니다**(교착). TTL 을 두면 일정 시간 뒤
자동으로 풀려 다른 워커가 진행할 수 있습니다. 즉 "영구 락"이 아니라 **임대(lease)** 입니다.

```perl
if ($l->{expires_at} <= _now()) { delete $LOCKS{$name}; return undef }
```

### 왜 토큰인가

락을 잡은 사람만 풀 수 있어야 합니다. 소유자 이름은 위조하기 쉬우니 **추측 불가능한
토큰**을 발급하고, 해제/갱신 시 대조합니다.

```perl
return $c->json({ error => 'token mismatch' }, 403) unless $token eq $held->{token};
```

### `409` + `Retry-After`

이미 점유 중이면 실패하되, **언제쯤 다시 시도**하면 좋을지 알려줍니다.

### 만료 판정은 접근 시점에

별도 타이머 없이, 락을 읽거나 쓸 때 만료 여부를 확인하고 정리합니다(지연 만료). 단순하고
견고한 방식입니다.

### 시계 정밀도

분 단위가 아니라 밀리초 단위 만료를 쓰려고 `Time::HiRes` 를 사용했습니다. 테스트에서
0.3초 TTL 로 만료를 즉시 재현할 수 있습니다.

## Notes

- 메모리 기반이라 단일 프로세스에서만 유효합니다. 실전은 Redis `SET NX PX` / ZooKeeper 등을
  씁니다.
- 네트워크 지연을 고려해 TTL 은 실제 작업 시간보다 넉넉히 잡고, 주기적으로 **갱신**합니다.
- 테스트는 획득/충돌/조회/갱신/해제/만료/검증을 확인합니다.
