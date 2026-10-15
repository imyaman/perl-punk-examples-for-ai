# Example 79 - 아웃바운드 웹훅 재시도 + 디드레터 (Punk + Perl)

이벤트를 외부 구독자에게 **재시도와 지수 백오프**를 곁들여 보내고, 모두 실패한 페이로드는
**디드레터**에 모으는 예제입니다.

- `POST /events` → 전송 시도 후 `202` (상태는 `delivered` 또는 `dead_letter`)
- 최대 3회 시도, 백오프는 1s → 2s 로 지수
- `GET /jobs[/:id]` → 시도 기록(`attempts_log`) 조회
- `GET /dead-letters` → 소진된 페이로드
- `POST /dead-letters/:id/retry` → 디드레터 재전송
- 테스트용 수신기 `POST /hook/sink` (`mode` 로 성공/실패를 왕복시킴)

## Routes

| Method | Path                     | Description |
|--------|--------------------------|-------------|
| GET    | /api/ping                | ping/pong |
| GET    | /api/healthz             | k8s liveness |
| GET    | /api/readyz              | k8s readiness |
| POST   | /events                  | 이벤트 전송(재시도) |
| GET    | /jobs                    | 작업 목록 |
| GET    | /jobs/:id                | 작업 상세(시도 기록) |
| GET    | /dead-letters            | 디드레터 |
| POST   | /dead-letters/:id/retry  | 디드레터 재전송 |
| POST   | /hook/sink               | 수신기(테스트용) |
| POST   | /hook/sink/mode          | 수신기 모드(ok/fail) |
| GET    | /hook/sink               | 수신 이벤트 확인 |

## 동작 방식 (왜 이렇게 될까)

### 왜 재시도인가

네트워크는 흔들리고 수신 서버는 잠깐 내려갑니다. **일시적 실패를 그대로 버리면 데이터가
유실**됩니다. 그래서 최대 N회 재시도합니다.

```perl
for my $i (1 .. $MAX_ATTEMPTS) { ... }
```

### 왜 지수 백오프인가

즉시 재시도하면 수신 서버가 회복할 틈이 없고, 부하를 키웁니다. `1s → 2s → 4s` 처럼 두
배로 늘리면 여유를 줍니다. 여기서는 **계산만 하고 기록**합니다 (예제를 빠르게 유지하기
위해 실제로는 기다리지 않음 — 실전은 워커 프로세스가 `sleep` 합니다).

```perl
$job->{next_retry_at} = time() + ($BACKOFF_BASE * (2 ** ($i - 1)));
```

### 전송은 2xx 일 때만 성공

HTTP 관점에서 `2xx` 는 수신자가 받았다는 뜻입니다. `4xx`(예: 페이로드 오류)이면 재시도해도
소용없으므로 곧바로 디드레터로 보냅니다. 이 예제는 단순화를 위해 **모든 실패를 재시도**로
취급합니다. 실전에서는 `4xx` 는 재시도하지 않고 `5xx`/타임아웃만 재시도합니다.

### 디드레터(DLQ)가 왜 필요한가

재시도를 다 쓴 페이로드는 버리면 **조용히 사라집니다**. DLQ 에 모아 두면 나중에 원인을
분석하고 재처리할 수 있습니다.

```perl
push @DEAD, { id => $job->{id}, attempts => $job->{attempts}, payload => $job->{payload} };
```

### 멱등성

수신자는 같은 이벤트를 여러 번 받을 수 있습니다. `event_id` 를 보내 **중복 처리를
방지**합니다. 이 예제의 수신기는 `event_id` 로 멱등 처리를 할 수 있습니다.

### 여기선 동기로 보낸 이유

재시도 흐름을 한눈에 보게 하려고 요청 안에서 전송을 수행했습니다. 실전에서는 이 흐름을
**백그라운드 워커**로 옮겨 요청을 빠르게 회신하고 재시도 상태를 저장소(예: Redis)에 둡니다
(cf. `example-26`).

### SSRF 주의

실제 서비스는 구독 URL 을 그대로 받아 요청하면 공격자가 내부망을 공격할 수 있습니다.
**허용 도메인 목록(allowlist)** 으로 검증하세요.

## Notes

- 이 예제는 수신기를 자기 자신에 둬 네트워크 없이 재시도를 재현합니다.
- 테스트는 성공/실패/3회 시도/DLQ/재전송/입력 검증을 검증합니다.
