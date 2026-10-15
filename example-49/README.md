# Example 49 - API 버저닝 (Punk + Perl)

두 가지 버저닝 전략을 한 예제에서 보여 줍니다: **URL prefix**(`/v1`, `/v2`)와
**Accept 미디어 타입**(`application/vnd.daeha.v2+json`).

- `GET /v1/items` — v1 형태(`items`)
- `GET /v2/items` — v2 형태(`data` + `meta.version`)
- `GET /items` + `Accept: application/vnd.daeha.vN+json` — 헤더 협상
- Accept 없으면 기본 v1

## Routes

| Method | Path       | Description |
|--------|------------|-------------|
| GET    | /api/ping  | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /v1/items  | v1 응답 |
| GET    | /v2/items  | v2 응답 |
| GET    | /items     | Accept 헤더(또는 기본 v1) |

## 동작 방식 (왜 이렇게 될까)

### URL prefix vs Accept 헤더

| 방식 | 장점 | 단점 |
|------|------|------|
| `/vN/...` | 명확, 캐싱/로그에 버전 노출 | 경로가 늘고 라우트 중복 |
| `Accept: vnd.…+json` | RESTful, URL 불변 | 프록시/캐시가 헤더 무시 가능, 디버깅 어려움 |

실무에선 둘을 섞거나, URL prefix 로 시작해 내부적으로 표현만 분기하기도 합니다.

### 형태 분리 헬퍼

버전별 표현을 `_v1` / `_v2` 서브로 분리하면 라우팅 로직이 깔끔해집니다. 공통 로직은
공유하고 **표현(shaping)** 만 다르게 가져가는 것이 핵심입니다.

```perl
sub _v1 { return { items => [ { id => 1, name => 'alpha' } ] } }
sub _v2 { return { data => [...], meta => { version => 2 } } }
```

### 커스텀 미디어 타입

`application/vnd.<vendor>.<resource>.v<N>+json` 관례를 쓰면 클라이언트가 원하는 표현을
명시적으로 요청할 수 있습니다. 응답의 `Content-Type` 도 그에 맞춰 돌려줍니다.

## Notes

- 테스트는 URL prefix 두 버전, Accept 협상 두 버전, 기본값 v1 을 검증합니다.
