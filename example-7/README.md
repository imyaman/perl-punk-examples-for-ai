# Example 7 - HTTP 메서드: get / post / put / patch / del / any (Punk + Perl)

같은 경로에서 HTTP 메서드별로 다른 핸들러를 연결하는 방법과,
모든 메서드에 응답하는 `any` 를 시연하는 예제입니다.

- `get` / `post` / `put` / `patch` / `del` — 메서드별 라우트
- `any` — 모든 메서드에 응답하는 라우트
- `$c->req->method` / `$c->req->path` 로 요청 메서드·경로 확인

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/item       | 현재 아이템 조회 |
| POST   | /api/item       | 생성 (201) |
| PUT    | /api/item       | 전체 교체 |
| PATCH  | /api/item       | 부분 갱신 |
| DELETE | /api/item       | 삭제 (상태 초기화) |
| ANY    | /api/echo       | 모든 메서드에 메서드/경로 에코 |

## 동작 방식 (왜 이렇게 될까)

### 메서드도 라우트 키의 일부다

Punk에서 라우트는 **(메서드, 경로)** 조합입니다. `get '/api/item'` 과
`put '/api/item'` 은 서로 다른 라우트로 등록되고, 디스패치 시 요청 메서드로
분기합니다. 그래서 같은 경로에 메서드별 핸들러를 자연스럽게 나열할 수 있습니다.
`patch` 는 HTTP PATCH 용도로 제공되며, 삭제는 `del` 키워드를 씁니다.

### `any` 는 메서드와 무관하게 매칭

`any '/api/echo'` 는 어떤 메서드로 들어와도 이 핸들러로 보냅니다. 핸들러 안에서
`$c->req->method` 로 실제 메서드를 읽어 응답을 만듭니다. 헬스체크나 프록시용
엔드포인트처럼 메서드를 가리지 않아야 할 때 씁니다.

### 미등록 메서드는 매칭 실패

`get` 만 등록된 경로에 `POST` 로 오면 그 (메서드, 경로) 조합이 없으므로 라우팅에
실패합니다. 메서드별로 다른 응답을 주고 싶으면 위처럼 핸들러를 각각 등록하면 됩니다.

### 상태 변경은 핸들러의 몫

PATCH(부분)/PUT(전체 교체)/POST(생성)의 차이는 프레임워크가 아니라 이 핸들러가
구현한 로직입니다. Punk는 (메서드, 경로)로 핸들러를 골라줄 뿐, 본문을 어떻게
해석하고 상태를 어떻게 바꿀지는 애플리케이션이 결정합니다.

## Notes

- 아이템은 인메모리입니다. DELETE 가 데모 상태로 되돌립니다.
