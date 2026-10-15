# Example 75 - 검색 + 자동완성 (Punk + Perl)

이름/태그 부분 일치 검색과 **prefix 자동완성**을 구현한 예제입니다.

- `GET /search?q=phone` → 이름(가중치 2)/태그(1) 점수 합산, 점수순 정렬
- `GET /search/suggest?prefix=ap` → 접두 일치 자동완성
- `limit` 으로 자동완성 개수 제한
- `q`/`prefix` 누락 → `400`

## Routes

| Method | Path             | Description |
|--------|------------------|-------------|
| GET    | /api/ping        | ping/pong |
| GET    | /api/healthz     | k8s liveness |
| GET    | /api/readyz      | k8s readiness |
| GET    | /search          | 부분 일치 검색 |
| GET    | /search/suggest  | prefix 자동완성 |

## 동작 방식 (왜 이렇게 될까)

### 점수 기반 랭킹

이름에 걸리면 2점, 태그에 걸리면 1점. 점수가 높은 것이 먼저 오고, 동점이면 id 순으로
**안정 정렬**합니다.

```perl
@hits = sort { $b->{score} <=> $a->{score} || $a->{id} <=> $b->{id} } @hits;
```

### 대소문자 무시

`lc` 로 정규화해 비교합니다. 대소문자를 구분하면 사용자가 놓치는 결과가 생깁니다.

### prefix 자동완성

`index(lc(name), lc(prefix)) == 0` 이면 접두 일치입니다. 결과는 **개수 제한**으로 잘라
응답을 가볍게 유지합니다.

### 전용 경로를 둔 이유

`/search`(결과) 와 `/search/suggest`(제안) 를 분리하면 각각 다른 캐시/성능 정책을 적용할
수 있고, 자동완성에 더 짧은 타임아웃을 걸 수 있습니다.

## Notes

- 메모리 내 데이터에 대한 단순 스캔입니다. 대규모에서는 역색인(예: Elasticsearch)을
  씁니다.
- 테스트는 부분 일치/대소문자/랭킹/자동완성/limit/입력 오류를 검증합니다.
