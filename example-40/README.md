# Example 40 - JSONP (Punk + Perl)

`?callback=foo` 쿼리 파라미터가 있으면 JSON 을 `foo({...});` 형태의
`application/javascript` 로 감싸서 반환하는 예제입니다. CORS 를 우회해야 했던
옛 브라우저 환경을 위한 패턴입니다.

- 콜백 이름을 정규식(`^[\w\.\$]+$`)으로 간단히 검증
- 잘못된 콜백은 `400 Bad Request` (Problem Details)
- `Content-Type: application/javascript; charset=utf-8` 설정

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /items    | `?callback=` 있으면 JSONP, 없으면 JSON |
| POST   | /items    | `{name:...}` → 201 + Location |
| GET    | /items/:id| 조회 |
| DELETE | /items/:id| 삭제 → 204 |

## 동작 방식 (왜 이렇게 될까)

### JSONP 란

브라우저는 동일 출처 정책 때문에 다른 도메인 API 의 JSON 을 `fetch/XHR` 로 못
가져왔습니다. `<script src="...">` 태그는 동일 출처 제한이 없어서, 콜백 이름을
파라미터로 붙여 스크립트로 내려주면 클라이언트가 전역 함수로 실행할 수 있었습니다.

```perl
sub _jsonp { my ($d,$cb) = @_; $cb . '(' . JSON::PP->new->encode($d) . ');' }
```

### 콜백 이름 검증 필수

콜백 파라미터를 그대로 `eval` 하듯 쓰면 XSS 위험이 커집니다. 여기서는 최소한
문자/숫자/언더스코어/점/달러만 허용하는 패턴으로 검증합니다(`jQuery123._0` 같은
공통 라이브러리 이름도 통과).

```perl
return _err400($c,'invalid callback') unless $cb =~ /^[\w\.\$]+$/;
```

### JSONP 는 GET 에만 쓰는 게 자연스러움

`<script>` 태그로는 GET 밖에 못 부르므로, JSONP 엔드포인트는 주로 읽기(GET)에만
사용했습니다. 여기서는 GET `/items` 만 JSONP 을 지원합니다.

## Notes

- 테스트는 `application/javascript` 타입, `foo({...});` 포맷, 유효/무효 콜백을 검증합니다.
