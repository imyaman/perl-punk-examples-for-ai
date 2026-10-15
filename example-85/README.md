# Example 85 - 역색인 전문 검색 (Punk + Perl)

문서를 **역색인(inverted index)** 으로 만들어 여러 질의어를 **AND** 로 검색하고, 빈도(tf)
로 랭킹하는 예제입니다. `example-75` 의 단순 부분일치보다 한 단계 깊은 구현입니다.

- `POST /documents` → 문서 색인(같은 id 는 교체)
- `GET /search?q=quick dog` → 모든 질의어 포함 문서 + 점수순
- `DELETE /documents/:id` → 색인에서 제거
- `GET /index/stats` → 문서/용어/포스팅 수

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| POST   | /documents      | 문서 색인 |
| GET    | /documents/:id  | 문서 원문 |
| DELETE | /documents/:id  | 문서 삭제 |
| GET    | /search         | 검색 |
| GET    | /index/stats    | 색인 통계 |

## 동작 방식 (왜 이렇게 될까)

### 역색인이란

`문서 → 단어` 가 아니라 **`단어 → 그 단어가 나온 문서들`** 로 뒤집어 저장합니다. 검색은
질의어의 포스팅 목록을 찾는 일이 되어 문서 전체를 훑지 않습니다.

```perl
%POST      # term => { docid => tf }   (tf = 문서 내 등장 횟수)
```

문서 하나를 색인하면:

```perl
$tf{$_}++ for _tokens($text);
$POST{$_}{$id} = $tf{$_} for keys %tf;
```

### 토큰화

`lc` 로 소문자화한 뒤 영숫자가 아닌 문자로 쪼갭니다. 그래야 `Quick,` 과 `quick` 이 같은
토큰이 됩니다.

```perl
return grep { length } split /[^a-z0-9]+/, lc($text);
```

### 여러 질의어는 AND(교집합)

`quick dog` 은 두 단어를 **모두** 가진 문서만 돌려줍니다.

```perl
%candidates = map { $_ => 1 } grep { $p->{$_} } keys %candidates;
```

### tf 로 랭킹

가장 단순한 점수는 질의어별 빈도 합입니다. `fox` 가 3번 나온 문서가 1번 나온 문서보다
앞섭니다. 점수가 같으면 id 순으로 안정 정렬합니다.

### 교체 시 이전 색인 제거

같은 id 를 다시 넣으면 **기존 postings 를 먼저 지우고** 새로 색인해야 낡은 단어가 검색에
남지 않습니다.

```perl
_unindex($id) if $existed;
_index($id, $text);
```

## Notes

- 실전 검색은 스톱워드 제거, 스테밍, BM25/TF-IDF, phrase/OR 검색, 샤딩까지 확장합니다.
- 메모리 기반이라 재시작하면 색인이 사라집니다.
- 테스트는 단일/AND/대소문자/랭킹/교체/삭제/통계/오류를 검증합니다.
