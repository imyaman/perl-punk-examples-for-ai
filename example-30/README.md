# Example 30 - 쿠키 설정/읽기/삭제 (Punk + Perl)

요청 쿠키 읽기와 응답 `Set-Cookie` 쓰기를 하나의 컨텍스트 메서드로 다루는 예제입니다.

- `$c->cookie('name')` — 요청 쿠키 읽기
- `$c->cookie('name' => $value, %opts)` — `Set-Cookie` 설정(체이닝)
- `undef` 값 → 쿠키 삭제
- 옵션: `path`(기본 `/`), `domain`, `max_age`, `secure`, `httponly`, `samesite`

## Routes

| Method | Path              | Description |
|--------|-------------------|-------------|
| GET    | /api/ping         | ping/pong |
| GET    | /api/healthz      | k8s liveness |
| GET    | /api/readyz       | k8s readiness |
| GET    | /cookie/set       | `daeha=tasty` 쿠키 설정 |
| GET    | /cookie/read      | 요청 쿠키 읽기 |
| GET    | /cookie/clear     | 쿠키 삭제 |

## 동작 방식 (왜 이렇게 될까)

### 한 메서드가 읽기와 쓰기를 겸한다

인자가 **하나면 요청 쿠키를 읽고**, **값과 옵션이 있으면 응답에 `Set-Cookie` 를
걸어 줍니다**. 쓰기 형태는 체이닝되므로 `$c->cookie(...)->json(...)` 처럼 이어 쓸
수 있습니다.

```perl
$c->cookie('daeha' => 'tasty', path => '/', max_age => 3600, httponly => 1);
```

### 삭제도 설정이다

`$c->cookie('daeha' => undef, ...)` 로 `undef` 를 넘기면 만료된 쿠키를 내려 보냅니다.
서버에 따로 삭제 로직이 있는 것이 아니라, **클라이언트에게 제거를 알리는 Set-Cookie**
입니다. 다음 요청부터는 읽히지 않습니다.

### 옵션이 곧 보안 설정

- `httponly` — 자바스크립트 접근 차단(XSS 유출 방지)
- `secure` — HTTPS 에서만 전송
- `samesite` — CSRF 완화(예제 17 과 맞물림)
- `path` / `domain` — 적용 범위

세션(예제 16) 쿠키도 결국 같은 방식의 서명 쿠키입니다. 여기서 다루는 것이 그
저수준 기반입니다.

## Notes

- 테스트는 쿠키 jar 로 설정 → 유지 → 삭제 흐름과 `Set-Cookie` 헤더를 검증합니다.
