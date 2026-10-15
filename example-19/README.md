# Example 19 - Bearer 토큰 인증 (Punk + Perl)

Punk 0.04 에는 `auth` 키워드가 없으므로, **가드로 직접** Bearer 토큰 인증을
구현하는 예제입니다. `Authorization: Bearer <token>` 을 검사해 보호 구역을 통제합니다.

- `under '/api/private' => $bearer` — 구역 전체 보호
- 헤더 파싱: `$c->req->header('authorization')` (대소문자 무관)
- 통과 시 `$c->stash->{user}` 에 인증 주체 저장

## Routes

| Method | Path                 | Description |
|--------|----------------------|-------------|
| GET    | /api/ping            | ping/pong (공개) |
| GET    | /api/healthz         | k8s liveness |
| GET    | /api/readyz          | k8s readiness |
| GET    | /api/private/me      | Bearer 토큰 필요 |
| GET    | /api/private/secret  | Bearer 토큰 필요 |

토큰: `tok-alice` (admin), `tok-bob` (user)

## 동작 방식 (왜 이렇게 될까)

### 인증도 결국 (메서드,경로) 앞의 함수

Punk의 가드는 컨텍스트를 받아 **reference 를 반환하면 거부**, 아니면 통과입니다
(예제 9). Bearer 인증도 같은 메커니즘으로 구현합니다: 헤더를 파싱하고, 토큰을
저장소에서 찾아 없으면 401 응답을 반환합니다.

### 헤더 이름은 대소문자 무관

`$c->req->header('authorization')` 은 HTTP 헤더 이름의 대소문자를 가리지 않습니다.
값은 `^Bearer\s+(\S+)$` 로 토큰만 뽑습니다.

### 두 단계 에러 구분

- 헤더 자체가 없음 → **401 missing bearer token**
- 헤더는 있으나 토큰이 무효 → **401 invalid token**

(`WWW-Authenticate: Bearer` 를 함께 보내는 것이 표준에 더 맞지만, 여기선 본문으로
구분합니다.)

### 통과한 주체는 `stash` 로 전달

토큰이 가리키는 `{ user, role }` 를 `$c->stash->{user}` 에 넣어, 뒤의 핸들러가
현재 사용자를 참조합니다. 전역 상태 없이 요청 단위로 전달됩니다.

## Notes

- 저장소는 데모용 인메모리 해시입니다. 실제로는 DB/캐시 조회로 대체합니다.
- 다음 예제(20)에서 Basic 인증, (21)에서 HMAC 서명을 다룹니다.
