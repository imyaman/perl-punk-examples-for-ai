# Example 41 - API Key 인증 (Punk + Perl)

간단한 API 키 기반 인증 예제입니다. 보호 라우트에서 `X-API-Key` 헤더 또는
`api_key` 쿼리 파라미터를 체크합니다.

- 유효 키: `demo-key`, `test-key`
- 키 누락/불일치 → `403 Forbidden` (RFC 7807 Problem Details)
- 공개 라우트는 그대로 접근 가능

## Routes

| Method | Path                 | Description |
|--------|----------------------|-------------|
| GET    | /api/ping            | ping/pong |
| GET    | /api/healthz         | k8s liveness |
| GET    | /api/readyz          | k8s readiness |
| GET    | /api/public/info     | 공개 |
| GET    | /api/protected/data  | 보호(`X-API-Key` 또는 `api_key`) |

## 동작 방식 (왜 이렇게 될까)

### 헤더 우선, 쿼리는 대안

여기서는 `$c->req->header('x-api-key') // $c->param('api_key')` 로 우선순위를 정합니다.
실서비스에서는 로그 노출 때문에 쿼리 파라미터에 키를 싣는 건 피하는 편이지만,
간단한 테스트 용도라 허용합니다.

```perl
my $key = $c->req->header('x-api-key') // $c->param('api_key');
unless (defined $key && $VALID_KEYS{$key}) {
    return _forbidden($c, 'invalid or missing api key');
}
```

### 인라인 가드 vs `under`

과거 예제(9)에서는 `under '/prefix' => $guard` 형태를 봤습니다. 기능상 똑같지만,
여기서는 엔드포인트 자체 안에서 체크해도 충분합니다. 어떤 방식이든
**가드가 HTTP 응답을 직접 반환하면 라우트 본문 실행을 차단**합니다.

### 403 + Problem Details

권한 거부는 `403 Forbidden` 이 적절합니다. (인증 자체 미흡은 보통 `401` 에 `WWW-Authenticate`
헤더를 붙이지만, 간소화 버전이라 `403` 과 Problem Details 를 사용합니다.)

## Notes

- 테스트는 공개 통과, 보호 실패(무키/오류키), 보호 성공(헤더/쿼리)을 검증합니다.
