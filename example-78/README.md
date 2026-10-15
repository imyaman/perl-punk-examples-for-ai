# Example 78 - RBAC, 역할 기반 접근 제어 (Punk + Perl)

**401(인증 실패)과 403(인가 실패)을 확실히 구분**하는 역할 기반 접근 제어 예제입니다.

- `POST /auth/login` → 로그인 성공 시 토큰 발급 (`201`)
- `GET /resource/public` → 인증 불필요
- `GET /resource/reader` → `reader` 역할 필요
- `GET /resource/admin` → `admin` 역할 필요
- 실패는 `application/problem+json` 으로 반환

| 사용자 | 역할 |
|--------|------|
| alice | reader |
| bob   | reader, admin |
| carol | (없음) |

## Routes

| Method | Path              | Description |
|--------|-------------------|-------------|
| GET    | /api/ping         | ping/pong |
| GET    | /api/healthz      | k8s liveness |
| GET    | /api/readyz       | k8s readiness |
| POST   | /auth/login       | 토큰 발급 |
| GET    | /resource/public  | 인증 불필요 |
| GET    | /resource/reader  | reader 필요 |
| GET    | /resource/admin   | admin 필요 |
| GET    | /account/me       | 내 정보 |

## 동작 방식 (왜 이렇게 될까)

### 401 과 403 을 섞으면 안 되는 이유

- **401 Unauthorized** — "누군지 모르겠다. 로그인해라."
- **403 Forbidden** — "너는 알지만, 이 자원에는 못 간다."

둘을 섞으면 클라이언트가 로그인을 반복해야 하는지 권한을 요청해야 하는지 알 수 없습니다.
또한 **인증을 먼저** 판단합니다. 토큰 없이 관리자 자원을 부르면 `403` 이 아니라 `401` 입니다.

```perl
my ($u, $err) = _auth($c);
return _unauthorized($c) if $err;                       # 401 먼저
return _forbidden($c, 'admin') unless _has($u, 'admin'); # 403 은 그다음
```

### 인증 실패에는 WWW-Authenticate

401 은 `WWW-Authenticate: Bearer` 헤더를 함께 보내야 합니다. 그래야 클라이언트가 인증
방식을 알아냅니다.

### 오류는 problem+json

Punk 의 `$c->json` 은 기본이 `application/json` 입니다. 오류에 `application/problem+json`
을 쓰려면 **직접 설정**해야 합니다. 그래야 RFC 9457 규격의 `type`/`title`/`status` 필드로
오류를 구조화해 클라이언트가 공통 처리를 할 수 있습니다.

```perl
$c->header('Content-Type' => 'application/problem+json');
return $c->json({ type => 'about:blank', title => 'Forbidden', status => 403,
                  required_role => $need }, 403);
```

### admin 이 reader 자원을 볼 수 있는 이유

bob 은 `reader` 와 `admin` 두 역할을 모두 가집니다. 역할은 **집합**으로 취급해 상위
역할이 하위 자원을 열람하도록 했습니다. 관리자용 페이지만 별도로 막고 싶다면 새 역할을
만들면 됩니다.

## Notes

- 이 예제는 메모리 기반이며, 재시작하면 토큰과 세션이 사라집니다.
- 실제 운영에서는 토큰 유효기간, 갱신, 서명 검증을 함께 도입합니다.
- 테스트는 로그인/역할/401/403/`WWW-Authenticate`/`problem+json` 을 검증합니다.
