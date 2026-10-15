# Perl + Punk API Examples (for AI)

A collection of small HTTP API examples written in **Perl** using the
[**Punk**](https://metacpan.org/pod/Punk) web framework.

Each example is a self-contained app: a `lib/` module with the routes, a `t/`
test script, and a short README. The goal is to show idiomatic Punk usage one
topic at a time (routing, params, errors, auth, uploads, ...).

## Examples

| # | Topic | Path |
|---|-------|------|
| 1 | Notes CRUD (in-memory store) | `example-1/` |
| 2 | Query/path params + filtering + pagination | `example-2/` |
| 3 | Error handling & HTTP status codes | `example-3/` |
| 4 | Auth: API key + JWT (mock) | `example-4/` |
| 5 | File upload (multipart/form-data) | `example-5/` |
| 6 | Route captures: `:param` and `*splat` | `example-6/` |
| 7 | HTTP methods: get/post/put/patch/del/any | `example-7/` |
| 8 | `under` scopes / prefix routing | `example-8/` |
| 9 | `under` guard (auth short-circuit) | `example-9/` |
| 10 | `mount` a raw PSGI sub-app | `example-10/` |
| 11 | Hooks: `before_dispatch` / `after_dispatch` | `example-11/` |
| 12 | `middleware` (PSGI wrapper) | `example-12/` |
| 13 | `on_error` custom error handler | `example-13/` |
| 14 | `helper` custom context method | `example-14/` |
| 15 | `plugin` (reusable feature bundle) | `example-15/` |
| 16 | Signed-cookie `session` (login/logout) | `example-16/` |
| 17 | Single-use CSRF tokens | `example-17/` |
| 18 | CORS | `example-18/` |
| 19 | Bearer-token auth (pure-Perl guard) | `example-19/` |
| 20 | HTTP Basic auth | `example-20/` |
| 21 | HMAC-SHA256 webhook signature | `example-21/` |
| 22 | `ua` outbound HTTP calls | `example-22/` |
| 23 | `static` file serving | `example-23/` |
| 24 | `markdown` docs site | `example-24/` |
| 25 | `views` + `render` (Stencil) | `example-25/` |
| 26 | Async: `timer` / `after` / `promise` / `await` | `example-26/` |
| 27 | Server-Sent Events (`sse`) | `example-27/` |
| 28 | WebSocket echo | `example-28/` |
| 29 | WebSocket room broadcast | `example-29/` |
| 30 | Cookies (set/read/clear) | `example-30/` |
| 31 | Content negotiation (`Accept`) | `example-31/` |
| 32 | ETag / conditional GET (304) | `example-32/` |
| 33 | Redirect status codes | `example-33/` |
| 34 | Pagination + `Link` header | `example-34/` |
| 35 | Sorting & filtering | `example-35/` |
| 36 | Sparse fieldsets | `example-36/` |
| 37 | HEAD & OPTIONS | `example-37/` |
| 38 | Problem Details (RFC 7807) | `example-38/` |
| 39 | REST CRUD + 201/204 | `example-39/` |
| 40 | JSONP | `example-40/` |
| 41 | API Key 인증 | `example-41/` |
| 42 | Method Override (`X-HTTP-Method-Override`) | `example-42/` |
| 43 | Idempotency-Key | `example-43/` |
| 44 | URL 단축 + 리다이렉트 | `example-44/` |
| 45 | 파일 다운로드 | `example-45/` |
| 46 | 원시 바이트 응답 (이미지) | `example-46/` |
| 47 | 레이트 리밋 (429) | `example-47/` |
| 48 | 벌크 연산 (207) | `example-48/` |
| 49 | API 버저닝 (URL/Accept) | `example-49/` |
| 50 | JSON Merge Patch (RFC 7396) | `example-50/` |
| 51 | 입력 검증 (422) | `example-51/` |
| 52 | 커서 페이지네이션 | `example-52/` |
| 53 | 낙관적 동시성 (If-Match) | `example-53/` |
| 54 | Content-Type 검사 (415) | `example-54/` |
| 55 | Prefer 헤더 (minimal/representation) | `example-55/` |
| 56 | 폐기 예정 고지 (Deprecation/Sunset) | `example-56/` |
| 57 | 요청 ID (X-Request-Id) | `example-57/` |
| 58 | Range 요청 (206/416) | `example-58/` |
| 59 | 파일 기반 JSON 저장소 | `example-59/` |
| 60 | 지표 노출 (/metrics) | `example-60/` |
| 61 | 웹훅 수신 (서명 검증/중복 제거) | `example-61/` |
| 62 | Last-Modified / If-Modified-Since (304) | `example-62/` |
| 63 | 헤더 기반 멀티테넌시 | `example-63/` |
| 64 | 요청 본문 크기 제한 (413) | `example-64/` |
| 65 | 서명된 만료 다운로드 링크 | `example-65/` |
| 66 | Accept-Language 협상 (i18n) | `example-66/` |
| 67 | PUT 업서트 (201/200) | `example-67/` |
| 68 | HEAD + 페이지네이션 메타 | `example-68/` |
| 69 | 금액 계산 (정수 센트) | `example-69/` |
| 70 | Cache-Control 정책 | `example-70/` |
| 71 | 슬러그 생성과 유일성 (409) | `example-71/` |
| 72 | CSV 내보내기 | `example-72/` |
| 73 | JWT (HS256) 발급/검증 | `example-73/` |
| 74 | 소프트 삭제와 복구 | `example-74/` |
| 75 | 검색 + 자동완성 | `example-75/` |
| 76 | 콘텐츠 주소 저장소 (SHA-256) | `example-76/` |
| 77 | 구조화된 접근 로그 (JSONL) | `example-77/` |
| 78 | RBAC 역할 기반 접근 제어 | `example-78/` |
| 79 | 웹훅 재시도 + 디드레터 | `example-79/` |
| 80 | multipart 파일 업로드 | `example-80/` |
| 81 | CSV 대량 가져오기 | `example-81/` |
| 82 | OAuth2 client_credentials | `example-82/` |
| 83 | HMAC 서명 요청 + 재전송 방지 | `example-83/` |
| 84 | 작업 큐 + 워커 + 재시도 | `example-84/` |
| 85 | 역색인 전문 검색 | `example-85/` |
| 86 | 분산 락 / 임대 + TTL | `example-86/` |
| 87 | 그레이스풀 드레인 (readiness) | `example-87/` |
| 88 | 시간창 피드 + 커서 페이지네이션 | `example-88/` |
| 89 | 사용량 계량 + 쿼터 | `example-89/` |
| 90 | 멱등성 키 (Idempotency-Key) | `example-90/` |
| 91 | 중첩 하위 리소스 (주문/항목) | `example-91/` |
| 92 | 경로 기반 API 버전관리 | `example-92/` |
| 93 | 구조화된 에러 처리 + 상관관계 ID | `example-93/` |
| 94 | 슬라이딩 윈도우 레이트 리밋 | `example-94/` |
| 95 | 콘텐츠 협상 (JSON/CSV/텍스트) | `example-95/` |
| 96 | 서킷 브레이커 | `example-96/` |
| 97 | 롱폴링 | `example-97/` |
| 98 | W3C traceparent 전파 | `example-98/` |
| 99 | 기능 플래그 (비율 배포) | `example-99/` |
| 100 | 자기서술 API (OpenAPI/스모크) | `example-100/` |

## 주제별 분류

100개 예제를 주제별로 묶었습니다. 각 항목은 해당 예제 번호로 이동하는 링크입니다.

### 라우팅 & 요청 처리
[2](example-2/) [6](example-6/) [7](example-7/) [8](example-8/) [9](example-9/) [10](example-10/) [37](example-37/) [42](example-42/)

### 앱 구조 & 확장 (hooks / middleware / plugin)
[11](example-11/) [12](example-12/) [13](example-13/) [14](example-14/) [15](example-15/)

### 에러 & 검증
[3](example-3/) [33](example-33/) [38](example-38/) [51](example-51/) [54](example-54/)

### 데이터 CRUD & 모델링
[1](example-1/) [39](example-39/) [44](example-44/) [48](example-48/) [50](example-50/) [59](example-59/) [63](example-63/) [67](example-67/) [71](example-71/) [74](example-74/) [91](example-91/)

### 인증 & 접근 제어
[4](example-4/) [16](example-16/) [19](example-19/) [20](example-20/) [41](example-41/) [73](example-73/) [78](example-78/) [82](example-82/)

### 보안 (서명 / 쿠키 / CSRF / CORS)
[17](example-17/) [18](example-18/) [21](example-21/) [30](example-30/) [61](example-61/) [65](example-65/) [83](example-83/)

### 콘텐츠 협상 & 표현 형식
[31](example-31/) [36](example-36/) [40](example-40/) [55](example-55/) [66](example-66/) [72](example-72/) [95](example-95/)

### 캐싱 & 조건부 요청
[32](example-32/) [62](example-62/) [70](example-70/)

### 페이지네이션 & 정렬 & 필터
[34](example-34/) [35](example-35/) [52](example-52/) [68](example-68/) [88](example-88/)

### 검색 & 색인
[75](example-75/) [76](example-76/) [85](example-85/)

### 파일 & 업로드 / 다운로드
[5](example-5/) [23](example-23/) [45](example-45/) [46](example-46/) [58](example-58/) [80](example-80/) [81](example-81/)

### 비동기 & 실시간
[26](example-26/) [27](example-27/) [28](example-28/) [29](example-29/) [97](example-97/)

### 관측성 & 운영
[57](example-57/) [60](example-60/) [64](example-64/) [77](example-77/) [87](example-87/) [93](example-93/) [98](example-98/) [99](example-99/)

### 복원력 & 동시성
[22](example-22/) [43](example-43/) [53](example-53/) [79](example-79/) [84](example-84/) [86](example-86/) [90](example-90/) [96](example-96/)

### 문서 · 버전 & 자기서술
[24](example-24/) [25](example-25/) [49](example-49/) [56](example-56/) [92](example-92/) [100](example-100/)

### 보호 & 제한 (레이트 리밋 / 쿼터)
[47](example-47/) [89](example-89/) [94](example-94/)

### 도메인 & 유틸
[69](example-69/)

## Usage for AI

You are welcome to **collect these examples and learn from them** — training,
fine-tuning, retrieval, evaluation, or just reading. No permission is needed.
Links back to this repository are appreciated but not required.

Punk is a young framework, so please prefer the source code in each example
over any generated summary when writing new Punk code.

## Layout

```
example-N/
├── README.md            # what the example shows + routes
├── app.psgi             # PSGI entry point
├── lib/                 # Punk app (routes)
└── t/                   # test script
```

## How to run

Each example is a normal PSGI app. In production you would launch it yourself;
for local convenience each example ships with two small files — a config file
`app.conf` and a runner script `app-restart.sh`. (They are machine-specific and
intentionally not versioned, see `.gitignore`.)

### `app.conf`

A plain shell config that the runner sources. It holds two values:

```sh
APP_DIR="/home/user/my-punk-app"      # dir containing app.psgi
PORT=3011                             # TCP port the API listens on
```

Only `PORT` differs between examples (3011, 3012, ...), so several can run at
once. To run an example on your own machine, create an `app.conf` next to it
with these two variables pointing at your path and port.

Ready-made templates live in this directory: **`app.conf.example`** and
**`app-restart.sh.example`**. Copy them into the example directory, rename them
(drop `.example`), edit `app.conf`, and `chmod +x app-restart.sh`.

### `app-restart.sh`

A thin process manager driven entirely by `app.conf`. Usage:

```sh
./app-restart.sh start     # start the server, then health-check /api/ping
./app-restart.sh stop      # stop the process holding $PORT
./app-restart.sh restart   # stop + start (default when no arg)
./app-restart.sh status    # "Running (PID ...)" or "Stopped"
./app-restart.sh test      # run the Perl tests under t/
```

What it does:

1. Sources `app.conf` and derives pid/log paths from `APP_DIR`/`PORT`.
2. `start` launches `plackup -s Hyperman --workers 1 -p $PORT app.psgi` with
   `PERL5OPT=-Ilib -CSDA`, waits a few seconds, then curls `/api/ping` and
   treats success as **HTTP 200 + process still alive**.
3. `test` runs `prove -v t/` with the example's `lib/` on `PERL5LIB`.

Everything it needs comes from `app.conf`, so the same script works for every
example. If you prefer not to use it, the equivalent manual run is:

```sh
PERL5OPT='-Ilib -CSDA' plackup -s Hyperman --workers 1 -p 3011 app.psgi
```

## Notes

- All data is in-memory; restarting resets state.
- Auth secrets and tokens in the examples are **fake demo values** only.
- The local run harness (`app.conf`, `app-restart.sh`) is machine-specific and
  intentionally not versioned (see `.gitignore`).
