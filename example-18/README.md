# Example 18 - CORS (cross-origin resource sharing) (Punk + Perl)

브라우저의 교차 출처 요청을 허용/거부하는 CORS 설정 예제입니다. 프리플라이트
(OPTIONS)를 라우팅 전에 자동 응답하고, 모든 응답에 CORS 헤더를 붙입니다.

- `cors origins => [...], credentials => 1, paths => ['/api']`
- 프리플라이트는 **라우팅 전에** 처리 → 별도 OPTIONS 라우트 불필요
- `Allow-Methods` 는 라우터에서 산출 → 앱이 안 서비스하는 메서드는 약속하지 않음

## Routes

| Method  | Path            | Description |
|---------|-----------------|-------------|
| GET     | /api/ping       | ping/pong |
| GET     | /api/healthz    | k8s liveness |
| GET     | /api/readyz     | k8s readiness |
| GET     | /api/data       | CORS 대상 엔드포인트 |
| OPTIONS | /api/*          | 프리플라이트 자동 응답 |

허용 오리진: `https://app.example.com` (자격증명 허용)

## 동작 방식 (왜 이렇게 될까)

### 두 가지 일을 한 곳에서

CORS는 (1) **프리플라이트 응답**과 (2) **응답 헤더 부착** 두 가지입니다.

- 프리플라이트(OPTIONS)는 **라우팅 전에** 답합니다. 그렇지 않으면 OPTIONS 라우트가
  없는 경로에서 라우터의 405가 나가버립니다.
- 헤더 부착은 **디스패처를 나가면서** 합니다. 404·405 는 컨텍스트를 만들지 않으므로
  after_dispatch 훅이 아니라 디스패처 레벨이어야 헤더가 붙습니다. (브라우저가 상태를
  읽어야 할 때가 바로 그럴 때입니다.)

### `credentials` 는 명시적 오리진을 요구

`credentials => 1` 이면 브라우저는 `*` 를 거부합니다. 요청 오리진을 그대로 반사하면서
자격증명까지 허용하면 **모든 사이트가 인증된 응답을 읽는** 전형적 CORS 구멍이 되므로,
Punk는 `to_app` 에서 croak 합니다. 그래서 여기선 오리진을 명시합니다.

### CORS 는 접근 제어가 아니다

CORS는 **브라우저에게** 어느 스크립트가 응답을 읽어도 되는지 알려줄 뿐입니다.
curl 은 신경 쓰지 않습니다. "특정 호출자를 막아야" 하면 헤더가 아니라 **가드**가
필요합니다(예제 9). CSRF 대체도 아닙니다 — 허용된 교차 출처 POST 도 유효한 토큰이
필요합니다(예제 17).

## Notes

- `paths => ['/api']` 로 CORS 를 API 구역에만 적용합니다.
