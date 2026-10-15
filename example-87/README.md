# Example 87 - Graceful drain: 레디니스 vs 라이브니스 (Punk + Perl)

서버를 내릴 때 **진행 중인 요청은 마치되 새 트래픽은 받지 않도록** 만드는 드레인 패턴
예제입니다. 라이브니스(살아있음)와 레디니스(받을 준비됨)를 분리하는 이유를 보여줍니다.

- `POST /admin/drain` → 드레인 시작(레디니스 실패)
- `POST /admin/resume` → 복귀
- `GET /api/readyz` → 드레인 중이면 `503`
- `GET /api/healthz` → 드레인 중에도 `200`
- `GET /work` → 처리 중인 요청 수(`in_flight`) 노출

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | 라이브니스 (항상 200) |
| GET    | /api/readyz     | 레디니스 (드레인 시 503) |
| GET    | /work           | 작업 처리 + in_flight |
| POST   | /admin/drain    | 드레인 시작 |
| POST   | /admin/resume   | 복귀 |
| GET    | /admin/state    | 현재 상태 |

## 동작 방식 (왜 이렇게 될까)

### 라이브니스 vs 레디니스

| 프로브 | 질문 | 드레인 중 |
|--------|------|-----------|
| liveness (`healthz`) | 프로세스가 살아있나? | `200` (재시작하면 안 됨) |
| readiness (`readyz`) | 트래픽을 받아도 되나? | `503` (로드밸런서가 제외) |

둘을 섞으면 **드레인 도중 프로세스가 재시작**되어 버립니다. 그래서 분리합니다.

```perl
get '/api/readyz' => sub {
    my ($c) = @_;
    return $c->json({ status => 'draining', ready => JSON::PP::false }, 503) if $DRAINING;
    return $c->json({ status => 'ready', ready => JSON::PP::true, in_flight => $IN_FLIGHT });
};
```

### in_flight 계측은 훅에서

모든 요청의 시작/끝을 `before_dispatch`/`after_dispatch` 훅에서 세면, 핸들러마다 코드를
넣지 않아도 진행 중인 요청 수를 셀 수 있습니다.

```perl
hook before_dispatch => sub { $IN_FLIGHT++; return };
hook after_dispatch  => sub { $IN_FLIGHT-- if $IN_FLIGHT > 0; return };
```

주의: 계측값은 **자기 자신도 포함**하므로, 요청 도중 조회하면 항상 1 이상입니다. 값이
계속 커지지 않으면 누수가 없다는 뜻입니다.

### `JSON::PP::true/false` 를 쓰는 이유

`1`/`0` 을 넣으면 JSON 에서 숫자로 나가 클라이언트가 boolean 으로 보지 않을 수 있습니다.
명시적 boolean 을 사용합니다.

### 드레인 순서(실전)

1. `drain` 호출 → 레디니스 `503` → LB 가 트래픽 제거
2. `in_flight` 가 0 이 될 때까지 대기
3. 프로세스 종료

## Notes

- 실제 종료 시그널(SIGTERM) 처리와 연동하면 무중단 배포에 쓸 수 있습니다.
- 드레인 중에도 이미 열린 요청은 정상 처리되어야 합니다(여기서는 `/work` 로 확인).
- 테스트는 readyz/healthz 분리/드레인/멱등/resume/in_flight 누수 없음을 검증합니다.
