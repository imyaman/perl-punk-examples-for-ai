# Example 95 - 콘텐츠 협상 (JSON / CSV / 텍스트) (Punk + Perl)

`Accept` 헤더에 따라 **같은 데이터를 여러 형식**으로 돌려주고, 맞는 형식이 없으면 `406`
을 주는 예제입니다.

- `Accept: application/json` → JSON
- `Accept: text/csv` → CSV
- `Accept: text/plain` → 텍스트
- 지원 형식 없음 → `406 application/problem+json`
- `Accept` 없으면 JSON 기본

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /report      | Accept 에 따라 형식 선택 |

## 동작 방식 (왜 이렇게 될까)

### 협상은 품질값(q) 순서로

`Accept` 는 `타입;q=가중치` 목록입니다. `q` 가 높은 순으로 정렬해 **지원하는 첫 형식**을
고릅니다.

```perl
@ranked = sort { $b->[0] <=> $a->[0] } @ranked;
for my $r (@ranked) { ... return 'csv' if $type eq 'text/csv'; ... }
```

예: `application/xml, text/csv;q=0.5` → xml 은 미지원이라 건너뛰고 csv 선택.

### 왜 `406` 인가

원하는 형식을 하나도 못 맞추면 `200` 으로 엉뚱한 형식을 주면 안 됩니다. **받아들일 수
없다**는 뜻으로 `406 Not Acceptable` 을 주고, 어떤 형식이 가능한지 알려줍니다.

### 와일드카드

`*/*` 나 `application/*` 는 관대한 클라이언트이므로 기본 형식(JSON)으로 처리합니다.

### 형식마다 `Content-Type` 을 맞춘다

CSV 는 `text/csv`, 텍스트는 `text/plain` 으로 알려줘야 클라이언트가 파싱 방법을 압니다.

```perl
$c->res->status(200);
$c->res->type('text/csv');
return $c->res->body(_csv());
```

### 직렬화만 분기, 데이터는 하나

같은 `@ROWS` 를 세 가지 직렬화로만 바꿉니다. 데이터 로직과 표현을 분리하면
유지보수가 쉽습니다.

## Notes

- 대용량 CSV 는 스트리밍(SSE/청크)으로 내보내는 편이 좋습니다.
- 형식 목록이 많아지면 `Vary: Accept` 를 붙여 캐시가 형식별로 갈라지게 합니다.
- 테스트는 json/csv/text/기본값/q 선택/406 을 검증합니다.
