# Example 83 - HMAC 서명 요청 + 재전송 방지 (Punk + Perl)

서버 간 요청에 **HMAC-SHA256 서명**을 붙여 위변조를 막고, 타임스탬프와 nonce 로 **재전송
공격**까지 막는 예제입니다.

- 서명 대상: `method \n path \n timestamp \n nonce \n sha256(body)`
- 서명 = `HMAC-SHA256(secret, 위 문자열)`
- 헤더: `X-Api-Key`, `X-Timestamp`, `X-Nonce`, `X-Signature`
- 시계 오차 ±300초, nonce 재사용 시 `409`

## Routes

| Method | Path          | Description |
|--------|---------------|-------------|
| GET    | /api/ping     | ping/pong (서명 불필요) |
| GET    | /api/healthz  | k8s liveness |
| GET    | /api/readyz   | k8s readiness |
| GET    | /resource     | 서명 필요 |
| POST   | /resource     | 서명 필요(본문 포함) |

## 동작 방식 (왜 이렇게 될까)

### 무엇에 서명하는가

본문만 서명하면 `GET` 요청을 보호할 수 없고, 경로만 서명하면 본문 조작을 막지 못합니다.
그래서 **메서드 + 경로 + 타임스탬프 + nonce + 본문해시**를 모두 이어붙여 서명합니다.

```perl
my $canon = join("\n", $method, $path, $ts, $nonce, sha256_hex($body));
my $sig   = hmac_sha256_hex($canon, $secret);
```

### 왜 본문은 해시로 넣는가

본문 전체를 서명 대상 문자열에 넣어도 되지만, **해시(고정 길이)** 로 넣으면 서명 문자열이
길어지지 않고 경계 문제(구분자 충돌)도 줄어듭니다.

### 타임스탬프 창으로 재전송 범위를 좁힌다

완벽한 서명도 **그대로 복사해 다시 보내면** 통과합니다. 타임스탬프가 `±300초` 밖이면
거부해 재사용 가능 시간을 제한합니다.

```perl
my $skew = time() - $ts;
return ... if $skew > $WINDOW || $skew < -$WINDOW;
```

미래 시각도 함께 막아야 합니다(시계를 앞당긴 서명을 무한정 쓸 수 있으므로).

### nonce 로 같은 요청의 재사용을 막는다

타임스탬프 창 안에서도 같은 요청을 두 번 쓰면 안 됩니다. `(key, nonce)` 를 기억해 두고
다시 오면 `409 Conflict` 로 거부합니다. 오래된 nonce 는 창을 벗어나면 정리합니다.

### 상수 시간 비교

서명 비교는 타이밍 공격을 피하도록 **상수 시간 비교**를 써야 합니다(`hmac_sha256_hex`
결과를 `eq` 로 비교하는 것은 값이 완전히 다를 때 조기 종료될 수 있음). 여기서는 예제의
단순화를 위해 `eq` 를 쓰지만, 실전에서는 `Digest::SHA`/`constant-time` 비교 함수를
사용합니다.

## Notes

- `secret` 은 절대 노출하지 말고 **키 회전**을 지원하도록 설계합니다.
- 서명 대상에 쿼리스트링까지 포함하면 더 강합니다(여기서는 경로만).
- 테스트는 정상/서명불일치/미지정키/만료/미래/비정상 ts/nonce 재사용/헤더 누락을 검증합니다.
