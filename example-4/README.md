# Example 4 - 인증: API 키 + JWT (Punk + Perl)

두 가지 인증 방식을 시연하는 예제입니다.

- **API 키 인증**: `X-API-Key` 헤더, 사전 등록된 키 대조
- **JWT 인증 (모의)**: `Authorization: Bearer <token>` 헤더, 모의 서명 검증 + 역할 기반 접근 통제(RBAC)

또한 **혼합 인증**(API 키 또는 JWT 중 하나) 와 **JWT 발급** 엔드포인트도 포함합니다.

> 주의: 이 예제의 JWT 는 실제 JWT 라이브러리가 아니라, 예제용 모의 서명(Digest::SHA 기반)입니다.
> 실제 운영 환경에서는 정식 JWT 라이브러리(Crypt::JWT 등)를 사용하세요.

## Routes

| Method | Path                       | Description |
|--------|----------------------------|-------------|
| GET    | /api/ping                  | ping/pong |
| GET    | /api/healthz               | k8s liveness |
| GET    | /api/readyz                | k8s readiness |
| GET    | /api/public                | 인증 불필요 |
| GET    | /api/private               | API 키 필요 (X-API-Key) |
| GET    | /api/admin                 | JWT 필요 + role=admin |
| GET    | /api/mixed                 | API 키 또는 JWT |
| POST   | /api/token                 | JWT 발급 (username, roles 전달) |

## 유효 API 키 (예제용)

- `demo-key-001` → alice, scopes: read, write
- `demo-key-002` → bob, scopes: read

## JWT 발급 예제

```bash
curl -s -X POST http://localhost:3014/api/token \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice","roles":["admin","user"]}'
```

발급받은 토큰을 사용:
```bash
curl -s http://localhost:3014/api/admin \
  -H "Authorization: Bearer <token>"
```

## 인증 실패 상태코드

- 400 Bad Request — 잘못된 인증 헤더 형식
- 401 Unauthorized — 키 없음 / 토큰 없음 / 토큰 무효
- 403 Forbidden — 토큰은 유효하지만 필요한 역할 없음

## 동작 방식 (왜 이렇게 될까)

### 인증은 "미들웨어"가 아니라 핸들러 코드

이 예제의 인증은 라우트별 핸들러 안에서 직접 처리합니다. `X-API-Key` 는
`$c->req->header('x-api-key')` 로, `Authorization` 은 `$c->req->header('authorization')`
로 읽습니다(Punk는 헤더 이름을 대소문자 구분 없이 다룹니다). 유효성 판정과
401/403/400 결정은 전적으로 핸들러 로직입니다.

### 요청 스코프 상태는 `$c->stash`

`/api/private`, `/api/admin`, `/api/mixed` 는 인증에 성공하면
`$c->stash->{auth} = { type => ..., info => ... }` 에 결과를 남깁니다. `stash` 는
**요청 하나에 묶인** 저장소라, 전역 변수 없이도 "이 요청이 어떻게 인증됐는지"를
뒷단 핸들러/응답에서 참조할 수 있습니다.

### 검증 실패 응답을 그대로 반환하는 패턴

`_authenticate_jwt` 는 실패 시 "응답(배열ref)"을 돌려주고, 핸들러는
`return $claims if ref $claims eq 'ARRAY';` 로 그 응답을 그대로 흘려보냅니다.
즉 **에러 응답도 반환값**이라는 Punk 모델을 이용해, 인증 실패를 조용히 전파합니다.

### 모의 JWT

`header.payload.signature` 를 직접 만들고 `Digest::SHA` 로 서명을 흉내 냅니다.
`_verify_jwt` 는 서명을 다시 계산해 비교하고 payload 를 디코드합니다. 실제 서명
검증은 아니지만, 토큰 발급 → 헤더 전달 → 역할 검사(RBAC) 흐름을 그대로 보여줍니다.

> Punk 자체도 `auth`/`auth_guard`/`under` 같은 인증·가드 도구를 제공합니다.
> 이 예제는 그 대신 "맨손" 구현으로 원리를 드러내는 쪽을 택했습니다.

## Notes

- 저장소는 프로세스 인메모리이며, 워커 1개로 실행됩니다.
- 재시작 시 데이터 초기화.
