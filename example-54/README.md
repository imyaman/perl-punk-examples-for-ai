# Example 54 - Content-Type 검사와 415 (Punk + Perl)

POST 본문의 미디어 타입을 검사해 잘못된 타입은 `415 Unsupported Media Type`, 깨진
JSON 은 `400 Bad Request` 로 거절하는 예제입니다.

- `application/json` (charset 파라미터 허용) 만 통과
- 그 외 타입/누락 → `415`
- 파싱 실패 → `400`

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| POST   | /echo     | `application/json` 요구 |

## 동작 방식 (왜 이렇게 될까)

### 415 vs 400

- `415 Unsupported Media Type`: **보낸 타입**이 처리 불가(예: `text/plain`)
- `400 Bad Request`: 타입은 맞지만 **내용**이 깨짐(예: 잘못된 JSON)

둘을 구분하면 클라이언트가 무엇을 고쳐야 하는지 명확해집니다.

### 파라미터 허용

`Content-Type: application/json; charset=utf-8` 처럼 파라미터가 붙는 경우가 흔하므로,
정규식으로 `application/json` 접두를 매칭합니다.

```perl
unless ($ct =~ m{^\s*application/json\b}i) {
    return _problem($c, 415, 'Unsupported Media Type', "...");
}
```

### 파싱 실패를 500 으로 두지 않는다

`$c->req->json` 이 예외를 낼 수 있으므로 `eval` 로 감싸고, 실패 시 `400` 으로
변환합니다. 클라이언트 잘못을 서버 오류로 위장하지 않는 게 중요합니다.

## Notes

- 테스트는 정상 JSON, charset 파라미터, `text/plain`, 타입 누락, 깨진 JSON 을 검증합니다.
