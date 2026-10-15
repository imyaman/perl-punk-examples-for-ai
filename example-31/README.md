# Example 31 - 콘텐츠 협상 (Accept 헤더) (Punk + Perl)

하나의 엔드포인트가 **`Accept` 헤더에 따라** JSON / HTML / plain 으로 응답하는
예제입니다. 지원하지 않는 타입은 `406 Not Acceptable` 을 돌려줍니다.

- `$c->req->header('accept')` — 요청 헤더 읽기(대소문자 무시)
- `$c->json` / `$c->html` / `$c->text` — 표현 선택
- `$c->json($data, 406)` — 상태 코드 지정

## Routes

| Method | Path          | Description |
|--------|---------------|-------------|
| GET    | /api/ping     | ping/pong |
| GET    | /api/healthz  | k8s liveness |
| GET    | /api/readyz   | k8s readiness |
| GET    | /negotiate    | Accept 에 따라 JSON/HTML/plain, 그 외 406 |

## 동작 방식 (왜 이렇게 될까)

### Accept 파싱 순서가 중요하다

와일드카드 `*/*` 는 "아무거나"라는 뜻이라 **모두와 매칭**됩니다. 따라서 명시적
타입(`text/html`, `text/plain`)을 **먼저** 확인하고, 와일드카드는 API 기본값인
JSON 으로 처리합니다.

```perl
my $accept = lc($c->req->header('accept') // '');
$accept = '*/*' if $accept eq '';
```

브라우저는 `text/html,...,*/*;q=0.8` 처럼 보내므로, 순서를 지키지 않으면 브라우저가
JSON 을 받는 황당한 일이 생깁니다.

### 형식 → 표현 매핑

| Accept | 응답 |
|--------|------|
| `application/json` 또는 `*/*` | JSON (`application/json`) |
| `text/html` | HTML |
| `text/plain` | 본문 텍스트 |
| 그 외 | `406` |

### 406 은 "내가 이 형식은 못 준다"는 정직한 거절

빈 응답이나 JSON 폴백으로 넘기는 대신, 클라이언트가 원한 표현을 줄 수 없음을 코드로
알립니다. `json($data, 406)` 처럼 두 번째 인자로 상태를 지정합니다.

## Notes

- 테스트는 각 Accept 케이스의 상태 코드·`Content-Type`·본문을 검증합니다.
