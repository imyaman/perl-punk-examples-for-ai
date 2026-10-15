# Example 6 - 라우트 캡처: `:param` 과 `*splat` (Punk + Perl)

경로에서 값을 뽑아내는 두 가지 캡처 문법을 시연하는 예제입니다.

- `:name` — 슬래시 하나를 사이에 둔 **단일 세그먼트** 캡처
- `*name` — 그 지점 **이후 경로 전체**를 잡는 와일드카드 캡처
- 캡처 값은 모두 `$c->param($name)` 으로 읽음

## Routes

| Method | Path                          | Description |
|--------|-------------------------------|-------------|
| GET    | /api/ping                     | ping/pong |
| GET    | /api/healthz                  | k8s liveness |
| GET    | /api/readyz                   | k8s readiness |
| GET    | /api/users/:id                | 단일 세그먼트 캡처 |
| GET    | /api/pairs/:left/:right       | 여러 캡처 |
| GET    | /api/files/*path              | 나머지 경로 전체 캡처 |

## 응답 예

```json
GET /api/users/42          -> {"resource":"user","id":"42"}
GET /api/pairs/foo/bar     -> {"left":"foo","right":"bar"}
GET /api/files/a/b/c.txt   -> {"path":"a/b/c.txt","segments":["a","b","c.txt"]}
```

## 동작 방식 (왜 이렇게 될까)

### 캡처는 라우터가 채우는 "경로 변수"

`get '/api/users/:id' => sub {...}` 에서 `:id` 는 정규식이 아니라 Punk 라우터의
**경로 세그먼트 변수**입니다. 라우트 매칭 시점에 그 세그먼트의 값이 캡처되고,
핸들러는 `$c->param('id')` 로 꺼냅니다. 그래서 직접 정규식을 쓰거나
경로를 파싱할 필요가 없습니다.

### `:name` 은 한 세그먼트, `*name` 은 나머지 전체

- `:id` — 슬래시로 구분된 **딱 한 칸**. `/api/users/42` 는 매칭되지만
  `/api/users/42/x` 는 매칭되지 않습니다.
- `*path` — 그 위치부터 **남은 경로 전체**(슬래시 포함)를 한 값으로 잡습니다.
  `/api/files/a/b/c.txt` → `path = "a/b/c.txt"`.

`param` 은 항상 문자열로 돌아오므로, 숫자가 필요하면 핸들러에서 변환합니다.

### 우선순위: OpenAPI 파라미터 → 경로 캡처 → 쿼리 → 폼

`$c->param($name)` 은 한 곳만 보지 않습니다. Punk는
OpenAPI 검증 파라미터 → 라우트 캡처 → 쿼리 문자열 → 폼 바디 순으로 찾습니다.
이 예제처럼 스펙 없이 쓰면 곧바로 "경로 캡처 → 쿼리 → 폼" 순으로 동작합니다.

### 경로 캡처 vs 쿼리 문자열

경로 캡처는 **라우트 매칭에 관여**하므로 `/api/users/42` 와 `/api/users/43` 이 같은
라우트로 들어옵니다. 반대로 쿼리 문자열은 매칭에 관여하지 않습니다(예제 2 참고).

## Notes

- 상태는 저장하지 않습니다(무상태 라우팅 데모). 재시작해도 동일하게 동작합니다.
