# Example 61 - 웹훅 수신 (서명 검증 + 중복 제거) (Punk + Perl)

외부 서비스가 보내는 웹훅을 **HMAC 서명으로 검증**하고, 같은 이벤트를 여러 번 보내도
한 번만 처리하는 예제입니다(멱등성). 예제 21 의 서명 생성과 짝을 이룹니다.

- `X-Signature: sha256=<hex>` 검증 (HMAC-SHA256)
- 서명 불일치/누락 → `401`
- 이벤트 ID 중복 → `200 { duplicate: 1 }`
- ID 누락 → `400`

## Routes

| Method | Path               | Description |
|--------|--------------------|-------------|
| GET    | /api/ping          | ping/pong |
| GET    | /api/healthz       | k8s liveness |
| GET    | /api/readyz        | k8s readiness |
| POST   | /webhooks/events   | 서명 검증 후 수신 |
| GET    | /webhooks/seen     | 수신한 이벤트 ID 목록 |

## 동작 방식 (왜 이렇게 될까)

### 왜 검증하는가

웹훅 엔드포인트는 공개되어 있어 누구나 POST 할 수 있습니다. 발신자와 공유한 **비밀키로
서명을 검증**해야 위조를 막을 수 있습니다.

```perl
my $expect = hmac_sha256_hex($raw, $SECRET);
```

**원문(raw body)** 에 서명하므로 파싱 전의 바이트를 그대로 써야 합니다.

### 타이밍 공격 방지

`eq` 로 비교하면 앞에서 몇 글자 맞는지에 따라 시간이 달라질 수 있습니다. **길이를 맞추고
전체를 XOR 누적**해 비교합니다(상수 시간 비교).

```perl
my $diff = 0;
$diff |= ord(substr($sig,$_,1)) ^ ord(substr($expect,$_,1)) for 0..length($expect)-1;
```

### 중복 제거(멱등성)

웹훅은 재전송될 수 있습니다. 이벤트 ID를 기록해 두고 이미 본 ID면 **부작용 없이**
`200` 을 돌려줍니다. 안 그러면 결제가 두 번 처리되는 등의 사고가 납니다.

## Notes

- 저장은 메모리 기반이라 재시작 시 초기화됩니다(실전에서는 DB/Redis 사용).
- 테스트는 정상/중복/위조/누락 서명/ID 누락을 검증합니다.
