# Example 35 - 정렬과 필터링 (Punk + Perl)

쿼리 파라미터로 목록을 **필터링**하고 **정렬**하는 예제입니다.

- 정확 일치: `name=`, `city=`
- 범위: `min_age=`, `max_age=`
- 정렬: `sort=-age,name` (쉼표 다중 키, `-` = 내림차순)
- 잘못된 정렬 필드는 `400`

## Routes

| Method | Path   | Description |
|--------|--------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /users | `?name=&city=&min_age=&max_age=&sort=` |

## 동작 방식 (왜 이렇게 될까)

### 필터 → 정렬 순서

먼저 행을 걸러 내고(`grep`), 그다음 정렬합니다. 필터를 먼저 해야 정렬 비용이
줄어듭니다.

```perl
@rows = grep { $_->{name} eq $v } @rows if defined $v;
```

### 정렬 명세 파싱

`-age,name` → `[['age',-1], ['name',1]]`. 필드 존재를 검증해 오타는 `400` 으로
거절합니다.

```perl
my $dir = ($key =~ s/^-//) ? -1 : 1;
return $c->json({ error => "unknown sort field: $key" }, 400)
    unless exists $USERS[0]{$key};
```

### 숫자/문자 자동 비교

같은 필드라도 값 성격에 따라 비교 연산자를 고릅니다(둘 다 숫자면 `<=>`, 아니면
`cmp`). `id`/`age` 는 숫자로, `name` 은 문자열로 정렬됩니다.

```perl
$r = (($av =~ /^\d+$/ && $bv =~ /^\d+$/) ? ($av <=> $bv) : ($av cmp $bv)) * $d;
```

### 동률 처리 = 다음 키로

비교 결과가 0(동률)이면 루프를 계속해 **다음 정렬 키**를 봅니다. Perl 의 `sort` 는
안정 정렬이라 명세에 없는 잔여 순서도 유지됩니다.

## Notes

- 테스트는 오름/내림, 다중 키 동률, 정확 일치/범위 필터, 결합, 잘못된 필드를 검증합니다.
