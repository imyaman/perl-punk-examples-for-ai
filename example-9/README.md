# Example 9 - `under` 가드로 인증 통제 (Punk + Perl)

`under` 스코프에 **가드(guard)** 를 붙여, 그 영역의 모든 라우트에 인증을
일괄 적용하는 예제입니다. API 키가 없으면 401, 틀리면 403, 맞으면 통과합니다.

- `under '/api/admin' => $guard` — 스코프 전체를 보호
- 가드는 요청마다 실행되며, **응답(reference)을 반환하면 즉시 종료**(short-circuit)
- 통과 시 `$c->stash` 에 인증 정보를 남겨 핸들러가 참조

## Routes

| Method | Path                  | Description |
|--------|-----------------------|-------------|
| GET    | /api/ping             | ping/pong |
| GET    | /api/healthz          | k8s liveness |
| GET    | /api/readyz           | k8s readiness |
| GET    | /api/admin/dashboard  | `X-API-Key: secret-key` 필요 |
| GET    | /api/admin/users      | `X-API-Key: secret-key` 필요 |

유효 키: `secret-key`

## 동작 방식 (왜 이렇게 될까)

### 가드는 스코프 앞에 끼워지는 함수

`under '/api/admin' => $require_key` 는 `/api/admin` 로 시작하는 모든 요청이
핸들러에 도달하기 **전에** `$require_key` 를 통과하게 만듭니다. 가드는 컨텍스트
`$c` 를 받는 평범한 서브루틴입니다.

### 반환값이 곧 판정

가드 규약은 단순합니다.

- **reference 를 반환하면** → 그 값을 응답으로 쓰고 요청을 끝냅니다(short-circuit).
  여기서는 `$c->json({...}, 401)` 같은 응답을 돌려줍니다.
- **아무것도 반환하지 않으면** → 통과, 다음 단계(핸들러)로 진행합니다.

`return;` 한 줄이 "통과"이고, 응답 객체를 반환하는 것이 "거부"입니다.

### 인증 결과는 `$c->stash` 로 전달

가드가 통과시키면서 `$c->stash->{auth} = { owner => 'alice' }` 처럼 요청 스코프
저장소에 값을 남기면, 뒤에 실행되는 핸들러가 같은 `$c->stash` 를 읽어 사용합니다.
전역 변수 없이 "이 요청을 누가 인증했는가"를 전달하는 방법입니다.

### 스코프에 한 번만 붙이면 전부 보호

`dashboard` 와 `users` 는 각자 인증 코드를 갖지 않지만 둘 다 보호됩니다.
스코프 단위로 가드를 걸면 새 라우트를 추가해도 자동으로 같은 정책을 따릅니다.

## Notes

- 상태를 저장하지 않는 무상태 데모입니다. 키는 예제용 하드코딩 값입니다.
