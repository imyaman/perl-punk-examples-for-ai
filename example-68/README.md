# Example 68 - HEAD + 페이지네이션 메타 (X-Total-Count / Link) (Punk + Perl)

목록 응답에 **전체 건수와 페이지 링크**를 헤더로 실어 보내고, `HEAD` 로는 같은 헤더만
본문 없이 돌려주는 예제입니다.

- `X-Total-Count`, `X-Page`, `X-Per-Page`
- `Link: <...>; rel="prev|next|first|last"`
- `HEAD /things` → 동일 헤더, 본문 없음

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET/HEAD | /things  | 페이지네이션 목록 |

## 동작 방식 (왜 이렇게 될까)

### 왜 HEAD 가 필요한가

`HEAD` 는 **헤더만** 원할 때(총건수·ETag 확인) 비용을 아껴줍니다. 헤더는 GET 과 같고
본문만 없습니다.

### HEAD 를 키워드로 받기

Punk 0.04 에는 `head` 키워드가 없습니다. 그래서 `any` 로 받아 `req->method` 로 분기하거나,
(기본 라우터가 `HEAD` 를 `GET` 핸들러로 매칭해 줍니다) 헤더 세팅 후 빈 본문을
반환합니다.

```perl
if ($c->req->method eq 'HEAD') {
    return $c->text('', 200);
}
```

### Link 로 다음/이전을 알려준다

URL 을 클라이언트가 구문 분석할 필요 없이 `Link` 헤더로 다음/이전/첫/마지막을 전달합니다
(RFC 8288). 프록시도 페이지를 추적하기 쉬워집니다.

### X-Total-Count

전체 건수는 본문을 렌더하지 않고도 `X-Total-Count` 로 줄 수 있어, `HEAD` 한 번으로
"총 몇 건인지"를 알 수 있습니다.

## Notes

- 테스트는 기본/마지막/중간 페이지, Link, HEAD 헤더·본문 없음을 검증합니다.
