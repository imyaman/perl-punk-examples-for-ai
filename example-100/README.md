# Example 100 - 자기서술 API (Self-describing) (Punk + Perl)

서비스가 **자기 자신을 설명**하는 예제입니다. 루트에서 버전·엔드포인트 목록을 알려주고,
`/openapi.json` 으로 기계가 읽는 명세를, `/_smoke` 로 핵심 점검을 제공합니다.

- `GET /` → 서비스 서술(버전, 엔드포인트, 링크)
- `GET /openapi.json` → 최소 OpenAPI 3 명세
- `GET /_smoke` → 스모크 체크 + `X-Smoke: pass`
- `GET /api/ping|healthz|readyz`

## Routes

| Method | Path           | Description |
|--------|----------------|-------------|
| GET    | /              | 서비스 서술 |
| GET    | /openapi.json  | OpenAPI 명세 |
| GET    | /_smoke        | 스모크 체크 |
| GET    | /api/ping      | ping/pong |
| GET    | /api/healthz   | 라이브니스(+uptime) |
| GET    | /api/readyz    | 레디니스 |

## 동작 방식 (왜 이렇게 될까)

### 루트가 곧 문서

`GET /` 가 사람과 기계 모두에게 **입구**가 됩니다. 클라이언트는 하드코딩 대신 루트를
탐색해 사용 가능한 엔드포인트를 발견합니다(HATEOAS 의 축소판).

```perl
return $c->json({
    service   => $SERVICE,
    version   => $VERSION,
    endpoints => [ { method => 'GET', path => '/api/ping', ... }, ... ],
    links     => { self => '/', openapi => '/openapi.json' },
});
```

### OpenAPI 명세

`/openapi.json` 은 **기계가 읽는** 계약입니다. 코드 생성·문서·테스트의 원천이 됩니다.

```perl
{ openapi => '3.0.3', info => { title => ..., version => ... }, paths => {...} }
```

### 스모크 체크 vs 헬스체크

| | 목적 |
|--|------|
| `/_smoke` | 배포 직후 **핵심 기능이 동작하는지** 점검 |
| `/api/healthz` | **프로세스가 살아있는지** (라이브니스) |
| `/api/readyz` | **트래픽을 받아도 되는지** (레디니스) |

### 버전을 한 곳에서

`$VERSION` 을 루트·OpenAPI·healthz 가 공유합니다. 버전 표기가 제각각이면 혼란스럽습니다.

### 발견 가능성(discoverability)

문서 URL 을 루트의 `links.documentation` 에 두면, 클라이언트가 **경로를 추측하지 않고도**
명세로 갈 수 있습니다.

## Notes

- 실제 OpenAPI 는 스키마/예시/보안 정의까지 포함합니다.
- 서술·명세는 배포 메타데이터(커밋 SHA, 빌드 시각)를 함께 넣으면 추적에 유용합니다.
- 테스트는 서술/목록 정확성/OpenAPI 형식/스모크/헬스/404를 검증합니다.

---

🎉 **100번째 예제**입니다. 앞선 99개 예제(검증·페이지네이션·캐싱·인증·동시성·관측성·
복원력 등)를 하나로 묶어 "스스로를 설명하는 API" 로 마무리합니다.
