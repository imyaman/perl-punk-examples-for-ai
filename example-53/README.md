# Example 53 - 낙관적 동시성 (If-Match / 412 / 428) (Punk + Perl)

`If-Match` 헤더로 **읽은 시점의 버전**을 함께 보내, 그 사이에 다른 사람이 수정했으면
덮어쓰지 않고 `412` 로 거절하는 예제입니다.

- `GET /doc` → `ETag` 포함
- `PUT /doc` 는 `If-Match` 필수
  - 누락 → `428 Precondition Required`
  - 불일치 → `412 Precondition Failed`
  - 일치(`*` 포함) → 갱신 후 새 `ETag`

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /doc      | 현재 문서 + ETag |
| PUT    | /doc      | If-Match 검증 후 갱신 |

## 동작 방식 (왜 이렇게 될까)

### Lost Update 문제

두 사람이 같은 문서를 읽고 각자 수정해 저장하면, 나중 저장이 앞 저장을 **덮어씁니다**.
이를 방지하려고 "내가 읽은 버전이 아직 그대로일 때만 저장"을 강제합니다.

### If-Match = 조건부 쓰기

1. 클라이언트가 `GET` 으로 문서를 읽고 `ETag` 를 저장
2. `PUT` 할 때 `If-Match: <ETag>` 를 보냄
3. 서버가 현재 `ETag` 와 비교 → 다르면 `412`

```perl
if ($im ne '*' && $im ne $etag) {
    return _problem($c, 412, 'Precondition Failed', '...');
}
```

`If-Match: *` 는 "리소스가 존재하기만 하면" 을 뜻하는 와일드카드입니다.

### 428 Precondition Required

`If-Match` 없이 그냥 덮어쓰면 동시성 보호가 무력화됩니다. 그래서 서버가 **조건부 요청을
강제**할 때 `428` 로 "If-Match 를 붙여서 보내라"고 알립니다.

### 갱신 시 새 ETag 발급

성공하면 내용이 바뀌므로 새 `ETag` 를 응답에 실어 보냅니다. 클라이언트는 다음 수정 때
이 값을 사용합니다.

## Notes

- 테스트는 누락/불일치/일치/와일드카드 및 새 ETag 발급을 검증합니다.
