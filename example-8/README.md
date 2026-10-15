# Example 8 - `under` 스코프 / 접두사 라우팅 (Punk + Perl)

`under` 로 공통 접두사를 묶어 API 버전과 중첩 영역을 구성하는 예제입니다.

- `under '/api/v1'` — 접두사 스코프 생성 후 `$scope->get(...)` 으로 라우트 추가
- 스코프를 **중첩**해 `/api/v1/admin` 같은 하위 영역 구성
- 한 경로에 여러 버전(v1, v2)을 나란히 정의

## Routes

| Method | Path                  | Description |
|--------|-----------------------|-------------|
| GET    | /api/ping             | ping/pong |
| GET    | /api/healthz          | k8s liveness |
| GET    | /api/readyz           | k8s readiness |
| GET    | /api/v1/status        | v1 상태 |
| GET    | /api/v1/items         | v1 목록 |
| GET    | /api/v2/status        | v2 상태 |
| GET    | /api/v1/admin/stats   | 중첩 스코프(admin) |

## 동작 방식 (왜 이렇게 될까)

### 스코프는 접두사를 붙이는 라우터

`my $v1 = under '/api/v1';` 는 그 접두사를 가진 **스코프 객체**를 돌려줍니다.
거기서 `$v1->get('/status' => ...)` 하면 실제 등록되는 경로는 `/api/v1/status`
가 됩니다. 전역 `get(...)` 은 그대로 최상위에 등록되고, 스코프 메서드는 접두사를
앞에 붙일 뿐 문법은 동일합니다.

### 중첩하면 경로가 쌓인다

`my $admin = under '/api/v1/admin';` 처럼 별도 접두사로 스코프를 만들거나,
스코프 안에서 다시 스코프를 열면 경로가 이어 붙습니다. 그래서 영역별로 라우트를
모아두되 실제 URL 은 조립됩니다.

### v1 과 v2 는 "같은 이름, 다른 접두사"

같은 `/status` 라도 `/api/v1/status` 와 `/api/v2/status` 는 접두사가 달라 별개
라우트입니다. 버전별 응답을 나란히 정의할 수 있는 이유가 이것입니다.

### 스코프가 곧 향후 가드의 자리

`under '/admin' => $guard` 처럼 스코프에 가드를 줄 수 있습니다(예제 15·16 참고).
지금은 가드 없이 접두사만 묶었지만, 스코프는 "이 영역 전체에 공통으로 적용할 것"
(가드·정책)의 자연스러운 위치입니다.

### 매칭 실패는 404

`/api/v3/status` 나 스코프 안의 미정의 경로(`/api/v1/unknown`)는 어떤 라우트와도
매칭되지 않아 404 가 됩니다.

## Notes

- 상태를 저장하지 않는 무상태 데모입니다.
