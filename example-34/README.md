# Example 34 - 페이지네이션 + Link 헤더 (Punk + Perl)

목록 API 에 페이지네이션을 붙이고, 다음/이전 페이지를 **RFC 5988 Link 헤더**로
알려 주는 예제입니다.

- `$c->param('page')`, `$c->param('per_page')` — 쿼리 파라미터
- `$c->header('Link' => ...)` — `rel="next|prev|first|last"`
- `return { data => [...], meta => {...} }`

## Routes

| Method | Path     | Description |
|--------|----------|-------------|
| GET    | /api/ping| ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /items   | `?page=&per_page=` 페이지 조회 + Link 헤더 |

## 동작 방식 (왜 이렇게 될까)

### 본문은 데이터, 헤더는 내비게이션

응답 본문에는 `data` 와 `meta`(page/per_page/total/pages)를 담고, 다음 페이지
위치는 **Link 헤더**로 알립니다. 클라이언트는 본문 구조를 몰라도 헤더만 보고
순회할 수 있습니다.

```
Link: </items?per_page=10&page=1>; rel="first",
      </items?per_page=10&page=2>; rel="next",
      </items?per_page=10&page=6>; rel="last"
```

### 경계 처리

- `per_page` 는 1~100 으로 제한(과도한 조회 방지)
- `page` 는 `1..pages` 로 **클램프**(범위 밖 요청도 안전)
- 마지막 페이지는 남은 개수만 반환

`first`/`last` 는 항상, `prev`/`next` 는 존재할 때만 넣습니다.

### offset 계산

```perl
my $start = ($page - 1) * $per;
my $end   = $start + $per - 1;
$end = $#ITEMS if $end > $#ITEMS;
```

0-based 슬라이스 `@ITEMS[$start .. $end]` 로 잘라 냅니다.

## Notes

- 테스트는 기본/마지막/커스텀 `per_page`/범위 초과 클램프와 Link 관계를 검증합니다.
