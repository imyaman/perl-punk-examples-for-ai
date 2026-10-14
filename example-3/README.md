# Example 3 - 에러 처리 & HTTP 상태코드 (Punk + Perl)

다양한 HTTP 상태코드와 일관된 에러 응답 형식을 시연하는 예제입니다.

## 상태코드 시연

- 200 OK — 기본 응답
- 400 Bad Request — 유효하지 않은 요청 (잘못된 JSON, 누락된 필드, 잘못된 인증 형식 등)
- 401 Unauthorized — 인증 누락 / 알 수 없는 토큰
- 403 Forbidden — 권한 부족 (토큰 DENY)
- 404 Not Found — 리소스 없음
- 409 Conflict — 리소스 충돌 (중복 등록)
- 422 Unprocessable Entity — 입력 검증 실패 (상세 필드 오류 포함)
- 429 Too Many Requests — 속도 제한 초과
- 500 Internal Server Error — 의도적 시뮬레이션

## Routes

| Method | Path                             | Description |
|--------|----------------------------------|-------------|
| GET    | /api/ping                        | ping/pong |
| GET    | /api/healthz                     | k8s liveness |
| GET    | /api/readyz                      | k8s readiness |
| GET    | /api/echo?code=404              | 상태코드 에코 (지정 코드로 응답) |
| POST   | /api/validate                    | 입력 검증 (422 + 필드 상세) |
| POST   | /api/register                    | 사용자 등록 (409 중복) |
| GET    | /api/secret                      | 인증 데모 (401/400/403) |
| GET    | /api/rate-limited-demo           | 속도 제한 데모 (429) |
| GET    | /api/simulate-error?mode=500     | 의도적 500 시뮬레이션 |

## 에러 응답 형식

간단한 형태:
```json
{ "error": "메시지" }
```

구조화된 형태:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "입력 검증 실패",
    "details": [ { "field": "email", "message": "email required" } ]
  }
}
```

## 동작 방식 (왜 이렇게 될까)

### 상태코드는 응답의 일부다

`$c->json($data, $status)` 의 두 번째 인자가 그대로 HTTP 상태코드가 됩니다.
`/api/echo?code=404` 처럼 한 엔드포인트에서 코드별 응답을 돌려줄 수 있는 것도,
상태코드가 라우트가 아니라 **응답의 속성**이기 때문입니다. 라우트는 `get '/api/echo'`
하나뿐이고, 무엇을 돌려줄지는 핸들러가 정합니다.

### 에러 응답 "형식"은 프레임워크가 아니라 규약

`{ error: { code, message, details } }` 같은 구조는 Punk가 강제하는 스키마가 아니라
이 예제가 정한 **앱 규약**입니다. Punk는 라우팅·컨텍스트·응답 직렬화만 담당하고,
본문 모양은 애플리케이션이 결정합니다. 그래서 4xx/5xx 모두 같은 골격으로 맞출 수 있습니다.

### `die` 는 500이 된다

`/api/simulate-error` 는 일부러 `die` 합니다. 핸들러에서 예외가 나면 Punk의 기본
에러 처리 경로를 타서 500으로 응답합니다(운영 환경에서는 스택트레이스 대신 일반
메시지). 커스터마이즈가 필요하면 `on_error`/hook 으로 바꿀 수 있다는 점이 Punk의 설계입니다.

### 인증 데모는 그냥 핸들러 코드

`authorization` 헤더는 대소문자 구분 없이 `$c->req->header('authorization')` 로 읽고,
`Bearer` 형식 검사 후 토큰 값을 비교하는 로직은 전부 핸들러 안에 있습니다.
401/403 을 언제 돌려줄지도 애플리케이션이 정합니다.

## Notes

- 저장소는 프로세스 인메모리이며, 워커 1개로 실행됩니다.
- 재시작 시 데이터 초기화.
