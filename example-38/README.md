# Example 38 - RFC 7807 Problem Details 에러 응답 (Punk + Perl)

API 에러를 **일관된 JSON 형식**으로 반환하는 예제입니다. `application/problem+json`
미디어 타입과 `type`, `title`, `status`, `detail`, `instance`, `errors` 같은 표준 필드를
사용합니다.

- 명시적으로 `Content-Type: application/problem+json` 설정
- `$c->json({...}, $status)` 로 상태 코드 함께 반환
- 문제 유형은 `about:blank` 로 단순화(정적 문서 없이)

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET/POST | /api/ping | ping/pong |
| GET/POST | /api/healthz | k8s liveness |
| GET/POST | /api/readyz  | k8s readiness |
| GET/POST | /fail/400 | 400 Bad Request (problem+json) |
| GET/POST | /fail/404 | 404 Not Found (problem+json) |
| GET/POST | /fail/422 | 422 Unprocessable Entity (problem+json) |

## 동작 방식 (왜 이렇게 될까)

### Problem Details (RFC 7807)

오류 응답을 `{type,title,status,detail,...}` 구조로 통일하면 클라이언트가 **에러를
프로그램적으로 해석**하기 쉬워집니다. `type` 은 문제 타입 식별 URI, `title` 은 사람이
읽기 쉬운 요약, `status` 는 HTTP 상태 코드, `detail` 은 구체적 설명입니다.

### Content-Type 은 반드시 명시

클라이언트가 이 포맷을 인식하게 하려면 `application/problem+json` 을 명시하는 게
바람직합니다. `$c->header('Content-Type' => 'application/problem+json')` 로 직접 지정한
뒤 `json()` 으로 본문을 내려 줍니다.

### 422 Unprocessable Entity

입력 형식은 맞지만 **의미상 유효하지 않은 경우**(검증 실패)는 `422` 가 적합합니다.
여기서는 `errors` 배열로 필드별 이슈를 나열합니다.

### `any()` 로 메서드 무관하게 실패 응답

실습 편의를 위해 같은 에러를 GET/POST 모두에 돌려줍니다.

## Notes

- 테스트는 각 상태 코드, `application/problem+json`, 바디의 `status/title/detail/errors`
  필드를 검증합니다.
