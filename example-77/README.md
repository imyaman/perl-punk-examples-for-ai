# Example 77 - 구조화된 접근 로그 (JSONL) (Punk + Perl)

모든 요청의 응답을 **JSON 한 줄**로 남기고 `/logs/tail` 에서 조회하는 예제입니다.

- `before_dispatch` 에서 시작 시각/요청 id 수집
- `after_dispatch` 에서 상태 코드까지 포함한 JSONL 기록
- `GET /logs/tail?n=` 로 마지막 N줄 조회

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /logs/tail  | 로그 마지막 N줄 |

## 동작 방식 (왜 이렇게 될까)

### 왜 구조화 로그인가

`GET /api/ping 200` 같은 사람이 읽는 로그는 그럴 듯하지만, **필터/집계가 어렵습니다**.
JSON 이면 `jq` 한 줄로 `status >= 500` 만 뽑거나 평균 응답시간을 계산할 수 있습니다.

```json
{"ts":1792065920,"rid":"..","method":"GET","path":"/api/ping","status":200,"ms":0.4}
```

### 훅으로 어디에도 침범하지 않게

개별 핸들러에 로그 코드를 복사하지 않고 훅 두 개로 전역 처리합니다.

- `before_dispatch`: 시작 시각(`Time::HiRes`) 저장
- `after_dispatch`: `$resp->[0]` (PSGI 상태 코드) 로 기록

### 요청 id 로 연결

`X-Request-Id` 를 로그에 넣어, 클라이언트가 준 그 id 로 여러 로그를 한 줄기로 추적할 수
있습니다.

### JSONL 포맷

`*.jsonl` 은 한 줄에 한 이벤트. 파일을 잘라 붙여도 분해가 쉽고, 무한히 이어붙이는
스트림 로깅과 잘 어울립니다.

## Notes

- 로그 위치는 `$ENV{DAEHA_ACCESS_LOG}` 로 지정(기본 `/tmp/daeha-access.jsonl`).
- 실제 운영에서는 비동기/로테이션(로그 감시)을 함께 도입합니다.
- 테스트는 필드/요청id/응답코드/지연/개수 제한을 검증합니다.
