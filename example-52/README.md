# Example 52 - 커서 페이지네이션 (Punk + Perl)

offset/page 대신 **불투명(opaque) 커서**로 다음 페이지를 가리키는 예제입니다.
`next_cursor` 를 그대로 다음 요청에 넘기면 이어서 조회됩니다.

- `GET /feed?limit=10` → 첫 페이지 + `next_cursor`
- `GET /feed?limit=10&cursor=<opaque>` → 다음 페이지
- 마지막 페이지는 `next_cursor = null`
- 잘못된 커서는 `400 Bad Request`

## Routes

| Method | Path       | Description |
|--------|------------|-------------|
| GET    | /api/ping  | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /feed      | `?limit=&cursor=` 커서 페이지네이션 |

## 동작 방식 (왜 이렇게 될까)

### offset vs cursor

`?page=5` 같은 offset 방식은:
- 뒤 페이지로 갈수록 느려짐(앞을 다 세어야 함)
- 그 사이 데이터가 삽입/삭제되면 **중복·누락** 발생

커서 방식은 **마지막으로 본 위치**에서 이어 읽어 안정적이고 빠릅니다.

### 커서는 불투명하게

커서를 그대로 노출하면 클라이언트가 조작하거나 내부 구현에 결합됩니다. 여기서는
`id:N` 을 base64url 로 감싼 **불투명 문자열**로 만들었습니다.

```perl
sub _enc_cursor { encode_base64url('id:' . $_[0]) }
```

### 서버는 커서를 검증한다

디코딩 후 형식이 맞지 않으면 `400` 을 돌려줍니다. 신뢰할 수 없는 입력이므로 항상
검증합니다.

```perl
my $id = _dec_cursor($cursor);
unless (defined $id) { ... 400 ... }
```

### 다음 페이지 존재 판단

`limit + 1` 개를 조회해 실제로 더 있는지 확인하는 기법도 흔합니다. 여기서는 남은 개수가
`limit` 보다 큰지로 `next_cursor` 를 결정합니다.

## Notes

- 테스트는 페이지 순회(전체 100개), 커서 연결, 잘못된 커서 400 을 검증합니다.
