# Example 56 - 폐기 예정 API 고지 (Deprecation / Sunset) (Punk + Perl)

구버전 엔드포인트가 **곧 폐기됨**을 표준 헤더로 알리는 예제입니다.

- `Deprecation: true`
- `Sunset: <HTTP-date>` — 폐기 예정 시각
- `Link: </v2/modern>; rel="successor-version"` — 대체 엔드포인트
- `Warning: 299 - "...deprecated..."`

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /v1/legacy   | 폐기 예정(고지 헤더 포함) |
| GET    | /v2/modern   | 대체 엔드포인트 |

## 동작 방식 (왜 이렇게 될까)

### 코드가 아니라 헤더로 알린다

기존 클라이언트를 깨지 않으려면 응답 본문/상태는 그대로 두고 **헤더로 예고**합니다.
클라이언트/모니터링이 `Deprecation`/`Sunset` 을 읽어 마이그레이션을 계획할 수 있습니다.

```perl
$c->header('Deprecation' => 'true');
$c->header('Sunset' => $http_date);   # RFC 7231 형식의 날짜
$c->header('Link' => '</v2/modern>; rel="successor-version"');
```

### Sunset 날짜 형식

HTTP 날짜(`Sun, 06 Nov 1994 08:49:37 GMT`)를 써야 합니다. `POSIX::strftime` 로 GMT
문자열을 만듭니다.

```perl
sub _http_date { strftime('%a, %d %b %Y %H:%M:%S GMT', gmtime($_[0])) }
```

### Warning (299)

구식이지만 `Warning: 299 - "..."` 로 사람이 읽을 문구를 덧붙일 수 있습니다.

## Notes

- 테스트는 `Deprecation`/`Sunset`/`Link`/`Warning` 및 신버전에 헤더가 없음을 검증합니다.
