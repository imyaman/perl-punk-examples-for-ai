# Example 45 - 파일 다운로드 (Punk + Perl)

`Content-Disposition: attachment; filename="..."` 헤더로 브라우저가 "열기"가 아니라
**파일 저장**하도록 유도하는 예제입니다.

- `text/plain`, `application/json`, `text/csv` 등 적절한 `Content-Type`
- `attachment` 으로 다운로드 강제
- 동적으로 생성한 문자열을 응답 본문으로 내려줌

## Routes

| Method | Path           | Description |
|--------|----------------|-------------|
| GET    | /api/ping      | ping/pong |
| GET    | /api/healthz   | k8s liveness |
| GET    | /api/readyz    | k8s readiness |
| GET    | /download/text | `hello.txt` 다운로드 |
| GET    | /download/json | `data.json` 다운로드 |
| GET    | /download/csv  | `users.csv` 다운로드 |

## 동작 방식 (왜 이렇게 될까)

### Content-Disposition

`attachment` 은 "파일로 저장해 달라"는 지시입니다. `inline` 이면 브라우저가
표현 가능한 타입(text/html, image/* 등)은 화면에 열려고 시도합니다.

```
Content-Disposition: attachment; filename="hello.txt"
```

파일명은 따옴표로 감싸는 게 안전합니다(공백 포함 시). UTF-8 파일명은 추가 파라미터로
처리하기도 하지만, 여기서는 간단히 ASCII 파일명만 사용합니다.

### 응답 생성 방식

- `text/plain/csv` → `$c->text($body)`
- `JSON` → `$c->json($data)` (이미 `application/json` 셋업)
- 모두 동적으로 생성된 콘텐츠이므로 "읽기 전용 파일 서빙"과는 다름

## Notes

- 테스트는 상태코드, `Content-Type`, `Content-Disposition` 의 `attachment`/`filename`,
  본문 내용을 검증합니다.
