# Example 44 - URL 단축 (Punk + Perl)

긴 URL 을 짧은 코드로 매핑해 `/sN` 형태로 접근하면 원래 URL 로 302 리다이렉트하는
예제입니다.

- `GET /shorten?url=` → 생성된 짧은 경로 `/sN` 반환
- `GET /:code` → 존재하면 `302 Location` 으로 원본 이동, 없으면 `404`
- 같은 URL 은 재사용
- `url` 형식은 간단히 `^https?://` 로 검증

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /shorten     | `?url=http...` → `{ short, url }` |
| GET    | /:code       | 코드 존재시 302 리다이렉트, 없으면 404 |

## 동작 방식 (왜 이렇게 될까)

### 단축 경로가 라우트 충돌을 일으킬 수 있다

`get '/:code'` 는 매우 광범위합니다. 만약 `/shorten` 같은 명시적 라우트가 먼저 정의돼
있으면, 라우터는 **더 구체적인 라우트**를 우선시하는 게 일반적입니다. Punk 0.04 도
실행 순서/구체성에 따라 경로가 선택될 것으로 보이지만, 실제 배포시엔 `/:code` 의
허용 문자 집합을 제한하는 게 안전합니다.

### 302 vs 301

단축 URL 은 보통 **일시적**으로 쓰이거나 통계/리다이렉트 추적이 필요하기에 `302` 가
많이 쓰입니다. 만약 영구 이동이라 확정되면 `301 Moved Permanently` 를 씁니다.

### 매핑 테이블은 메모리 기반

여기서는 `SHORT_TO_URL`, `URL_TO_SHORT` 두 해시로 양방향 매핑합니다. 재방문시
기존 코드를 재사용합니다. 프로세스 재시작 시 사라집니다.

## Notes

- 테스트는 유효성 검사, 생성 포맷, 302 리다이렉트, 미존재 404 를 검증합니다.
