# Example 57 - 요청 ID / 상관관계 (X-Request-Id) (Punk + Perl)

모든 요청에 고유 식별자를 부여하고 응답 헤더로 되돌려 주는 예제입니다. 클라이언트가
`X-Request-Id` 를 보내면 유효한 경우 그대로 사용하고, 없거나 형식이 틀리면 새로
생성합니다.

- `before_dispatch` 훅에서 처리
- 응답 헤더 `X-Request-Id` + JSON 본문에 동일 값
- 요청마다 고유

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /whoami     | 현재 request id 반환 |
| GET    | /echo       | id + path 반환 |

## 동작 방식 (왜 이렇게 될까)

### 왜 요청 ID 가 필요한가

분산 시스템에서 하나의 사용자 요청이 여러 서비스/로그에 흩어집니다. **상관관계 ID**가
있으면 로그를 한 줄기로 추적할 수 있습니다.

### before_dispatch 훅

라우팅 직후, 가드 실행 전에 `before_dispatch` 가 돌아 모든 요청에 일괄 적용됩니다.
개별 핸들러마다 코드를 넣을 필요가 없습니다.

```perl
hook before_dispatch => sub {
    my ($c) = @_;
    my $rid = $c->req->header('x-request-id');
    $rid = _gen_rid() unless defined $rid && $rid =~ /^[\x21-\x7e]{1,100}$/;
    $c->stash->{request_id} = $rid;
    $c->header('X-Request-Id' => $rid);
    return;
};
```

### 들어온 값 검증

외부 입력을 그대로 신뢰하면 헤더 주입/로그 오염 문제가 생깁니다. 그래서 **허용 문자와
길이**를 제한하고, 벗어나면 새로 생성합니다. `$c->header(...)` 는 핸들러가 반환되면서
응답에 함께 반영됩니다.

### stash 로 전달

`$c->stash` 는 요청 범위 해시입니다. 훅에서 저장하면 핸들러에서 꺼내 본문에 넣을 수
있습니다.

## Notes

- 테스트는 자동 생성, 들어온 값 유지, 잘못된 값 대체, 요청별 고유성을 검증합니다.
