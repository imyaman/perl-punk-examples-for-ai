# Example 84 - 작업 큐 + 워커 + 재시도 (Punk + Perl)

요청을 받아 **큐에 넣고 바로 응답**하고, 별도 워커가 하나씩 꺼내 처리하는 비동기 작업
패턴 예제입니다. 실패는 자동 재시도 후 **디드레터**로 보냅니다.

- `POST /jobs` → 큐 적재 (`202`, `Location`)
- `POST /worker/tick` → 대기열에서 **하나** 처리 (FIFO)
- `GET /jobs[/:id]` → 상태/결과
- `POST /jobs/:id/retry` → 실패 작업 재시도

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| POST   | /jobs           | 작업 등록 |
| POST   | /worker/tick    | 워커 1회 실행 |
| GET    | /jobs           | 상태 요약 |
| GET    | /jobs/:id       | 작업 상세 |
| POST   | /jobs/:id/retry | 실패 작업 재시도 |

## 동작 방식 (왜 이렇게 될까)

### 왜 큐인가

오래 걸리는 작업을 요청 안에서 처리하면 **응답이 느려지고 타임아웃**이 납니다. 등록만
받아 `202 Accepted` 로 알려주고, 실제 처리는 워커에 맡깁니다.

```
접수(202) ─▶ [queued] ─▶ [running] ─▶ [done]
                              └─ 실패 ─▶ [queued](재시도) ─▶ [failed]
```

### 상태 전이를 명확히

`queued → running → done | failed` 로 상태를 바꾸고, 시도 횟수(`attempts`)와 오류를
기록합니다. 클라이언트는 `GET /jobs/:id` 로 폴링합니다.

### 워커 tick 을 명시적으로 둔 이유

실제로는 백그라운드 프로세스가 루프를 돌지만, 예제에서는 **한 번의 처리 단위(`tick`)** 를
HTTP 로 노출해 재현/테스트가 쉬우며 FIFO 순서를 눈으로 확인할 수 있습니다.

### 재시도와 최대 시도 횟수

일시 실패는 자동 재시도하고, `max_attempts` 를 넘으면 `failed` 로 확정합니다.

```perl
if ($job->{attempts} < $job->{max_attempts}) { $job->{status} = 'queued'; push @QUEUE, $id }
else { $job->{status} = 'failed' }
```

### 실패 원인을 남긴다

`error` 필드에 실패 사유를 저장하면 상위 시스템이 판단/재시도할 수 있습니다.

## Notes

- 메모리 기반이라 재시작하면 큐가 비워집니다. 실전은 Redis/RDBMS 큐를 씁니다.
- 워커를 별도 프로세스로 돌리면 **동시성/락/가시성 타임아웃**을 함께 설계해야 합니다.
- 테스트는 등록/처리/자동 재시도/수동 재시도/FIFO/오류/빈 큐/검증을 포함합니다.
