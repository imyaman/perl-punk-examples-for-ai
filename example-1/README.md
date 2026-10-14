# Example 1 - 노트 CRUD HTTP API (Punk + Perl)

인메모리 저장소를 사용하는 간단한 노트 CRUD 예제입니다.

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong health check |
| GET    | /api/healthz    | k8s liveness probe (`status: ok`) |
| GET    | /api/readyz     | k8s readiness probe (`status: ready`) |
| GET    | /api/notes      | 노트 목록 조회 |
| POST   | /api/notes      | 노트 생성 (JSON body: `{ title, body }`) |
| GET    | /api/notes/:id  | 노트 상세 조회 |
| PUT    | /api/notes/:id  | 노트 갱신 |
| DELETE | /api/notes/:id  | 노트 삭제 |

## 동작 방식 (왜 이렇게 될까)

### `use Punk` 와 `to_app`

`lib/Daeha.pm` 상단의 `use Punk` 는 이 패키지에 라우팅 DSL(`get`/`post`/`put`/`del` …)과
애플리케이션 레지스트리를 심습니다. `app.psgi` 의 `Daeha->to_app` 는 그 라우트 표를
컴파일해 **PSGI 앱(coderef)** 으로 한 번 동결(freeze)해 돌려줍니다. 그래서 `app.psgi`
는 이 한 줄로 끝나고, plackup 같은 아무 PSGI 서버나 이 앱을 띄울 수 있습니다.

### 라우트는 "선언", 핸들러는 coderef

`get '/api/notes' => sub { ... }` 는 매 요청 실행되는 코드가 아니라, 모듈이 로드될 때
표에 등록되는 **선언**입니다. Punk는 라우트·가드·핸들러를 `to_app` 시점에 한 번
해석하고 동결하므로, 요청마다 경로를 다시 파싱하지 않고 미리 만든 표를 조회합니다.
파일 스코프에 라우트가 그냥 나열된 것도 이 때문입니다.

### 핸들러는 `$c` 하나를 받는다

핸들러는 `Punk::Context` 객체 하나(`$c`)를 받는 평범한 서브루틴이고, **그 반환값이
곧 응답**입니다. `$c->json($data)` 는 데이터를 JSON으로 직렬화해 응답을 만들며,
두 번째 인자로 상태코드를 줍니다(`$c->json($note, 201)`).

### 입력 읽기

- 경로 캡처 `/api/notes/:id` → `$c->param('id')`
- JSON 바디 → `$c->req->json` (파싱 실패는 예외 → `eval` 로 잡아 400)
- 쿼리 문자열 → `$c->req->query` (해시ref)

### 상태는 어디에 사는가 (인메모리 저장소)

`my %NOTES` 는 모듈 렉시컬이라 워커 프로세스가 살아있는 동안 유지되어 요청 간에
공유됩니다. 워커가 여러 개면 프로세스마다 복사본이 생겨 데이터가 갈라지므로,
인메모리 예제는 단일 워커(`--workers 1`)로 실행합니다.

## Notes

- 저장소는 프로세스 메모리(in-memory) 입니다. 워커가 여러 개면 데이터가 공유되지 않으므로,
  이 예제는 단일 워커(--workers 1) 로 실행됩니다.
- 재시작 시 저장소가 초기화됩니다.
