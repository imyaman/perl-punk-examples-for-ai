# Example 32 - ETag / 조건부 GET (304) (Punk + Perl)

리소스의 버전을 `ETag` 로 노출하고, `If-None-Match` 가 일치하면 본문 없이
`304 Not Modified` 로 응답하는 예제입니다.

- `$c->header('ETag' => $etag)` — 응답 헤더 설정
- `$c->req->header('if-none-match')` — 조건부 요청 헤더
- `$c->text('', 304)` — 상태 코드를 지정한 빈 304
- `return { ... }` — 해시ref 반환 → JSON (앞서 건 pending 헤더/상태가 합쳐짐)

## Routes

| Method | Path       | Description |
|--------|------------|-------------|
| GET    | /api/ping  | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /resource  | 200 + `ETag`, 일치 시 304 |
| PUT    | /resource  | 본문 갱신 후 새 `ETag` |

## 동작 방식 (왜 이렇게 될까)

### ETag = 내용의 지문

`ETag` 는 리소스의 특정 버전을 가리키는 문자열입니다. 여기서는 `rev:text` 를
MD5 로 해싱해 만듭니다. 내용이 바뀌면 ETag 도 바뀝니다.

```perl
sub _etag { '"' . md5_hex("$REV:$TEXT") . '"' }
```

### If-None-Match 는 "이 버전 있으면 안 줘도 돼"

클라이언트가 받은 ETag 를 `If-None-Match` 로 되돌려 보냅니다.

- 서버 ETag 와 **일치** → `304` (본문 없음, 대역폭 절약)
- **불일치** → `200` + 새 본문

```
$c->header('ETag' => $etag);
if (defined $inm && $inm eq $etag) {
    return $c->text('', 304);
}
return { rev => $REV, text => $TEXT };
```

### 빌더 상태가 응답에 합쳐진다

`$c->header(...)` 로 걸어 둔 헤더와 `$c->status(...)` 로 설정한 상태는, 뒤이어
해시ref를 반환해도 응답에 그대로 합쳐집니다. 그래서 "헤더 먼저, 본문은 마지막"이라는
자연스러운 순서가 됩니다.

### 304 에는 본문을 붙이지 않는다

표준상 `304` 응답은 본문을 가질 수 없습니다. `text('', 304)` 로 빈 본문을 돌려주는
것이 안전합니다. 캐시는 이때 기존에 받아 둔 본문을 그대로 재사용합니다.

## Notes

- 테스트는 최초 200 → 304 → 갱신(새 ETag) → 옛 ETag 는 200 → 새 ETag 는 304 흐름을
  검증합니다.
