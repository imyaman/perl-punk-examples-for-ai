# Example 60 - 지표 노출 (/metrics, Prometheus 포맷) (Punk + Perl)

`before_dispatch` 훅으로 요청을 세고, `/metrics` 에서 **Prometheus 텍스트 포맷**으로
노출하는 예제입니다.

- `daeha_requests_total{method,path}` counter
- `daeha_uptime_seconds` gauge
- `Content-Type: text/plain; version=0.0.4; charset=utf-8`
- `/metrics` 자기 자신은 집계에서 제외

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /metrics    | Prometheus 지표 |

## 동작 방식 (왜 이렇게 될까)

### 왜 Prometheus 텍스트 포맷인가

Prometheus/OpenMetrics 가 널리 쓰는 **줄 단위 텍스트** 포맷을 그대로 내보내면 별도
클라이언트 라이브러리 없이도 스크레이프할 수 있습니다.

```
# HELP daeha_requests_total Total HTTP requests handled
# TYPE daeha_requests_total counter
daeha_requests_total{method="GET",path="/api/ping"} 3
# TYPE daeha_uptime_seconds gauge
daeha_uptime_seconds 42
```

### 훅에서 세고 엔드포인트에서 읽는다

집계는 `before_dispatch` 에서, 노출은 `/metrics` 핸들러에서 합니다. 요청을 처리하는
모든 핸들러를 건드리지 않고도 전역적으로 계측됩니다.

### 자기 참조 방지

`/metrics` 스크레이프 자체를 세면 지표가 계속 증가해 혼란을 줍니다. 그래서 경로가
`/metrics` 이면 건너뜁니다.

### 라벨 이스케이프

라벨 값의 `"`·`\` 는 이스케이프해야 포맷이 깨지지 않습니다.

## Notes

- 이 지표는 프로세스 메모리 기반이라 재시작 시 초기화됩니다.
- 테스트는 카운터 라인/타입, 업타임, 자기 미집계를 검증합니다.
