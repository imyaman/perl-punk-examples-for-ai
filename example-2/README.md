# Example 2 - 쿼리/경로 파라미터 + 필터링 + 페이지네이션 (Punk + Perl)

아이템 목록을 대상으로 다음 기능을 시연하는 예제입니다.

- 경로 파라미터 `/api/items/:id` (특정 아이템 조회)
- 쿼리 파라미터 필터링: `?category=`, `?status=`, `?search=`
- 쿼리 페이지네이션: `?page=`, `?per_page=` (기본값/상한 처리 포함)
- 응답에 페이지네이션 메타 포함

## Routes

| Method | Path                         | Description |
|--------|------------------------------|-------------|
| GET    | /api/ping                    | ping/pong |
| GET    | /api/healthz                 | k8s liveness |
| GET    | /api/readyz                  | k8s readiness |
| GET    | /api/items                   | 목록 (필터 + 페이지네이션) |
| GET    | /api/items?category=tool     | 카테고리 필터 |
| GET    | /api/items?status=sold       | 상태 필터 |
| GET    | /api/items?search=eta        | 이름 검색 (부분일치) |
| GET    | /api/items?page=2&per_page=3 | 페이지네이션 |
| GET    | /api/items/:id               | 특정 아이템 상세 |

## 동작 방식 (왜 이렇게 될까)

### 경로 파라미터와 쿼리 파라미터는 읽는 곳이 다르다

Punk에서 `/api/items/:id` 의 `:id` 는 **경로 캡처**이고 `$c->param('id')` 로 읽습니다.
반면 `?category=tool` 같은 **쿼리 문자열**은 라우트 매칭에 관여하지 않고,
`$c->req->query` 로 읽는 평범한 해시ref입니다. 같은 "파라미터"라도 서로 다른
메커니즘이라는 점이 이 예제의 핵심입니다.

- 경로 캡처 → 라우터가 세그먼트를 매칭하며 채워줌 → `$c->param('id')`
- 쿼리 문자열 → 라우팅과 무관, 요청 객체에서 직접 파싱 → `$c->req->query`

### 같은 경로에 필터가 붙어도 라우트는 하나

`GET /api/items` 와 `GET /api/items?category=tool` 은 서로 다른 라우트가 아닙니다.
쿼리 문자열은 경로 매칭에 포함되지 않으므로 둘 다 `get '/api/items'` 하나로 들어오고,
핸들러 안에서 `$c->req->query` 를 보고 분기합니다. 그래서 라우트 표에 쿼리 변형이
여러 줄로 적혀 있어도 실제 등록된 라우트는 하나입니다.

### 필터링/페이지네이션은 프레임워크가 아니라 앱 로직

`grep` 으로 필터하고, `splice` 로 페이지를 자르고, `pagination` 메타를 붙이는 일은
전부 이 핸들러의 코드입니다. Punk는 라우팅·컨텍스트·응답만 제공하고, 목록 가공은
애플리케이션의 몫입니다. `per_page` 상한(100)과 `page` 보정도 여기서 직접 합니다.

### 핸들러는 `$c` 하나를 받는다

핸들러는 `Punk::Context`(`$c`)를 받고, `$c->json({...})` 의 반환값이 응답이 됩니다.
`$c->param`/`$c->req->query` 는 모두 이 컨텍스트를 통해 요청에 접근하는 창구입니다.

## Notes

- 저장소는 프로세스 인메모리입니다. 워커 1개(--workers 1)로 실행됩니다.
- 재시작 시 데이터 초기화.
- 쿼리 파라미터는 `$c->req->query` 로 읽으며, 경로 캡처(`:id`)는 `$c->param('id')` 로 읽습니다.
