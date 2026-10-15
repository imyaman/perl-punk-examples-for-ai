# Example 48 - 벌크 연산 (Punk + Perl)

여러 개의 생성/수정/삭제를 **한 요청**으로 처리하고, 작업별 결과를 배열로 돌려주는
예제입니다.

- 요청: `POST /bulk` + `{ "ops": [ {op, ...}, ... ] }`
- `create` / `update` / `delete` 지원
- 전부 성공 → `200`, 일부 실패 → `207 Multi-Status`
- 결과를 `results[]` 로 항목별 상태 보고

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| POST   | /bulk       | ops 배열 실행, 200/207 |
| GET    | /store      | 현재 상태 |

## 동작 방식 (왜 이렇게 될까)

### 한 번의 왕복, 여러 작업

N개 작업을 개별 요청으로 보내면 N번의 네트워크 왕복이 듭니다. 벌크는 이를 1회로
줄여 지연과 오버헤드를 낮춥니다. 대신 **부분 실패** 처리가 핵심이 됩니다.

### 207 Multi-Status

모든 작업이 성공하면 `200`. 하나라도 실패하면 `207 Multi-Status` 로 알리고, 각
작업의 상태는 `results[]` 안에 담습니다.

```perl
return $c->json({ ok => ($ok ? 1 : 0), results => \@results }, $ok ? 200 : 207);
```

### 항목별 결과 보고

각 항목은 `{op, status, id}` 형태로 결과를 남깁니다. 클라이언트는 어떤 작업이
왜 실패했는지 배열 인덱스로 대응시킬 수 있습니다.

### 원자성(all-or-nothing)은 아님

여기서는 앞선 작업이 실패해도 뒤 작업을 계속 수행합니다(best-effort). 진짜 트랜잭션이
필요하면 전체를 검증 후 적용하거나 롤백해야 합니다.

## Notes

- 테스트는 정상/부분실패/알 수 없는 op 흐름을 검증합니다.
