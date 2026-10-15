# Example 93 - 구조화된 에러 처리 (Punk + Perl)

처리기가 예외로 죽어도 **일관된 `problem+json`** 으로 응답하고, 요청마다 **상관관계 ID**
를 붙여 로그와 응답을 연결하는 예제입니다.

- 모든 요청에 `X-Correlation-Id` 부여(들어온 값은 존중)
- `on_error` 로 예외를 잡아 `500 application/problem+json`
- 예외 상세는 로그로, 클라이언트에는 안전한 형태로
- 정상/오류 모두 같은 ID 로 추적 가능

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /ok          | 정상 응답 |
| GET    | /boom        | 즉시 예외 |
| GET    | /divzero     | 런타임 예외 |
| GET    | /chain       | 하위 함수에서 예외 |

## 동작 방식 (왜 이렇게 될까)

### 상관관계 ID

`before_dispatch` 에서 요청마다 ID 를 만들고 응답 헤더와 stash 에 넣습니다. 클라이언트가
`X-Correlation-Id` 를 보내면 그대로 이어받아 **분산 추적**이 가능합니다.

```perl
hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('X-Correlation-Id') // sha1_hex(time().rand());
    $c->stash->{rid} = $rid;
    $c->header('X-Correlation-Id' => $rid);
};
```

### `on_error` 한 곳에서

`Punk` 의 `on_error` 는 가드/처리기가 죽으면 실행됩니다. **참조를 반환하면 그게 응답**이
됩니다.

```perl
on_error sub {
    my ($c, $err) = @_;
    warn "[error][$c->stash->{rid}] $err\n";     # 자세한 건 로그로
    $c->res->status(500);
    $c->res->type('application/problem+json');
    return $c->res->body(JSON::PP->new->encode({ ... 'correlation_id' => $rid ... }));
};
```

### 왜 `problem+json` 인가

`application/problem+json`(RFC 7807)은 `type/title/status/detail` 을 표준 필드로
정의합니다. 클라이언트가 오류를 **기계적으로** 처리할 수 있습니다.

### 내부 정보 노출 주의

스택트레이스나 DB 오류 문구를 그대로 클라이언트에 주면 보안에 취약합니다. 자세한 내용은
**로그**로, 응답에는 `correlation_id` 만 주어 운영자가 대조하게 합니다.

### 한 곳에서 처리하는 이유

핸들러마다 `eval {}` 를 두면 빠뜨리기 쉽습니다. `on_error` 로 모으면 **일관성**이 생기고
응답 형식이 통일됩니다.

## Notes

- 미정의 경로는 프레임워크 기본 `404` 로 처리됩니다.
- `correlation_id` 를 로그에 남기면 장애 시 요청-로그-응답을 즉시 연결할 수 있습니다.
- 테스트는 예외→500/로그 상관ID/헤더 에코/미정의 경로 404를 검증합니다.
