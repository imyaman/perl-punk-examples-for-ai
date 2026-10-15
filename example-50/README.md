# Example 50 - JSON Merge Patch (RFC 7396) (Punk + Perl)

`PATCH` 요청에 **JSON Merge Patch** 시맨틱을 적용하는 예제입니다.

- 스칼라 값 → 교체
- 객체 값 → **재귀 병합**
- `null` 값 → 해당 키 **삭제**
- 배열 값 → 통째로 교체(객체가 아니므로)
- `PUT` 은 전체 문서 교체

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /doc      | 현재 문서 |
| PUT    | /doc      | 전체 교체 |
| PATCH  | /doc      | Merge Patch 적용 |

## 동작 방식 (왜 이렇게 될까)

### Merge Patch 규칙

JSON Merge Patch 는 "패치 문서를 대상에 병합"하는 규칙입니다.

| 패치 값 | 결과 |
|---------|------|
| `null` | 키 삭제 |
| 객체 | 재귀 병합 |
| 그 외(스칼라/배열) | 그 값으로 교체 |

```perl
if (!defined $v)            { delete $target->{$k}; }
elsif (ref $v eq 'HASH')    { $target->{$k} = _merge_patch($target->{$k}, $v); }
else                        { $target->{$k} = $v; }
```

### 배열은 "통째 교체"라는 점에 주의

Merge Patch 는 배열의 원소 단위 병합을 지원하지 않습니다. 배열을 주면 **전부 교체**
됩니다. 특정 원소만 고치고 싶다면 전체 배열을 보내거나, JSON Patch(RFC 6902) 같은
연산 기반 포맷을 써야 합니다.

### null 의 이중 의미

JSON 에서 `null` 은 "값이 널"이라는 뜻이지만, Merge Patch 에서는 "키 제거"를
의미합니다. 그래서 어떤 키를 **명시적 null 로 설정**하는 것은 불가능합니다.

## Notes

- 테스트는 스칼라 교체, 중첩 병합/삭제, 배열 교체, 객체 null 삭제, PUT 전체 교체를
  검증합니다.
