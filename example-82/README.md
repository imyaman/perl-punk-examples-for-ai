# Example 82 - OAuth2 client_credentials (Punk + Perl)

머신 간 통신에 쓰는 **OAuth2 client credentials** 흐름을 최소 구현한 예제입니다. 토큰
발급, 스코프 검사, introspection 까지 다룹니다.

- `POST /oauth/token` → `client_credentials` 로 access token 발급
- `GET /resource/data` → `Bearer` 토큰 + `read` 스코프 필요
- `POST /introspect` → 토큰 상태/스코프 조회

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| POST   | /oauth/token    | 토큰 발급 |
| GET    | /resource/data  | 보호 자원 |
| POST   | /introspect     | 토큰 조회 |

### 클라이언트

| client_id | secret   | 허용 스코프     |
|-----------|----------|-----------------|
| appA      | s3cr3t   | read, write     |
| appB      | b-secret | write           |

## 동작 방식 (왜 이렇게 될까)

### 요청 스코프는 허용 스코프의 부분집합이어야 한다

클라이언트가 가진 권한보다 많은 스코프를 요청하면 거부합니다.

```perl
for my $s (@want) {
    return _oauth_error($c, 400, 'invalid_scope', "not granted: $s")
        unless $allowed{$s};
}
```

`scope` 를 생략하면 허용된 전체를 부여합니다.

### `401` 과 `403` 의 구분 (RFC 6750)

| 상황 | 상태 | `error` |
|------|------|---------|
| 토큰 없음/위조/만료 | `401` | `invalid_token` |
| 토큰은 유효, 스코프 부족 | `403` | `insufficient_scope` |

`WWW-Authenticate` 헤더에 이유를 담아 클라이언트가 대응하게 합니다.

```
WWW-Authenticate: Bearer error="insufficient_scope", scope="read"
```

### grant_type 검사

`client_credentials` 만 지원합니다. 다른 값은 `unsupported_grant_type`(`400`) 으로
명확히 거부해, 클라이언트가 잘못된 흐름을 시도했음을 알 수 있게 합니다.

### introspection 을 둔 이유

자원 서버가 토큰 자체를 검증할 수 없는 구조(예: opaque 토큰)에서 토큰 상태를 물어보는
표준 엔드포인트입니다. 유효하지 않으면 `active: false` 만 돌려줍니다(정보 최소 노출).

## Notes

- client secret 은 **환경변수/시크릿 저장소**로 관리해야 합니다. 여기서는 예제용 하드코딩입니다.
- 실전에서는 JWT(UserSub)나 서명 토큰으로 자원 서버가 introspection 없이 검증하기도 합니다.
- 테스트는 발급/스코프/401/403/introspection 을 검증합니다.
