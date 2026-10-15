# Example 81 - CSV 대량 가져오기 (Punk + Perl)

업로드한 CSV 를 **행 단위로 검증**하고, 좋은 행만 적재한 뒤 실패 행을 줄 번호와 함께
돌려주는 예제입니다.

- `POST /import` → CSV 업로드 후 적재
- 결과: `{ imported, skipped, errors: [{line, error}], total }`
- 필수 열 `name`, `price` (헤더 검사 → 없으면 `422`)
- 빈 이름/숫자가 아닌 가격은 건너뛰고 오류 목록에 기록
- `.csv` 가 아니면 `415`

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz | k8s readiness |
| POST   | /import   | CSV 가져오기 |
| GET    | /records  | 적재 결과 |

## 동작 방식 (왜 이렇게 될까)

### all-or-nothing 이 아니라 부분 성공

대량 가져오기는 한 줄 오류로 전체를 버리면 비효율적입니다. **좋은 행은 넣고, 나쁜 행은
목록으로 보고**합니다. 실패 목록에는 반드시 **줄 번호**를 넣어야 사용자가 원본에서 고칠
수 있습니다.

```perl
push @errs, { line => $line, error => 'price must be a non-negative number' };
```

### 최소 CSV 파서

`Text::CSV` 없이도 필요한 만큼만 구현합니다. 핵심은 **따옴표 안의 쉼표**와 **`""` 이스케이프**
를 처리하는 것입니다.

```
"Widget, large",19.99      → 이름에 쉼표 포함
"Say ""hi""",3.5           → 이름에 따옴표 포함
```

문자 단위 상태 기계(인용 안/밖)로 처리합니다.

### 헤더를 먼저 검증

열 이름을 소문자/공백 정리 후 인덱스로 매핑하고, 필수 열이 없으면 본문을 읽기 전에
`422` 로 끊습니다. 그래야 의미 있는 오류를 빠르게 돌려줍니다.

### 왜 `422` 인가

문법은 맞지만(CSV 는 파싱됨) **의미상 처리할 수 없음**(필수 열 누락)이므로 `422
Unprocessable Entity` 가 적절합니다. 형식 자체가 틀리면 `400` 입니다.

## Notes

- 실전에서는 스트리밍 파싱, 트랜잭션, 대량 INSERT 로 확장합니다.
- 업로드는 메모리에 담기므로 큰 파일은 별도 스트리밍 구성이 필요합니다.
- 테스트는 적재/건너뛰기/줄번호/인용 처리/헤더 검증/형식 오류를 검증합니다.
