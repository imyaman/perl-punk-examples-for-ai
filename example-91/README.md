# Example 91 - 중첩 하위 리소스 (주문 + 항목) (Punk + Perl)

`/orders/:id/items` 처럼 **상위 리소스 아래에 하위 리소스**를 두는 REST 모델링 예제입니다.
주문 상태(`open`/`submitted`)에 따라 하위 리소스 조작을 막습니다.

- `POST /orders` → 주문 생성(`open`)
- `GET /orders/:id` → 합계(`total_cents`) 포함
- `POST /orders/:id/items` → 항목 추가
- `GET /orders/:id/items` → 항목 목록
- `DELETE /orders/:id/items/:itemId` → 항목 삭제
- `POST /orders/:id/submit` → 제출(항목 없으면 `422`)

## Routes

| Method | Path                        | Description |
|--------|-----------------------------|-------------|
| POST   | /orders                     | 주문 생성 |
| GET    | /orders/:id                 | 주문 + 합계 |
| GET    | /orders/:id/items           | 항목 목록 |
| POST   | /orders/:id/items           | 항목 추가 |
| DEL    | /orders/:id/items/:itemId   | 항목 삭제 |
| POST   | /orders/:id/submit          | 제출 |

## 동작 방식 (왜 이렇게 될까)

### 중첩은 "소유 관계"를 표현

항목은 주문 없이 존재할 수 없습니다. URL 에 부모 id 를 두면 소속이 드러나고, 권한/검증도
부모 기준으로 하기 쉬워집니다.

```perl
del '/orders/:id/items/:itemId' => sub { ... }
```

### 하위 리소스 조작은 상태에 달려 있다

주문이 `submitted` 면 항목을 더하거나 지울 수 없습니다(`409`). 상태 전이를 **자원 계층에
반영**하는 전형적인 패턴입니다.

```perl
return $c->json({ error => 'order is not open' }, 409) unless $o->{status} eq 'open';
```

### 합계는 파생값

`total_cents` 는 항목에서 계산합니다. 저장하지 않고 매번 계산하면 정합성이 깨질 일이
없습니다(읽기 비용과의 트레이드오프).

### 빈 주문 제출은 `422`

형식은 맞지만(주문 존재) **의미상 처리 불가**하므로 `422` + `code: empty_order` 로
이유를 구체화합니다.

### 하위 리소스 404 vs 상위 409

없는 주문에 항목을 넣으면 `404`(상위 없음), 제출된 주문에 넣으면 `409`(상태 충돌).
두 상황을 구분해야 클라이언트가 올바르게 대응합니다.

## Notes

- 라우트에 파라미터가 둘 이상(`:id`, `:itemId`) 있어도 정상 동작합니다.
- 실전에서는 하위 리소스에도 페이지네이션/정렬을 붙입니다.
- 테스트는 생성/항목 CRUD/합계/제출/상태 전이 차단/빈 제출을 검증합니다.
