# Example 37 - HEAD & OPTIONS (Punk + Perl)

하나의 라우트에서 `GET / HEAD / OPTIONS` 를 다루는 예제입니다. `any()` 를 쓰거나
메서드별로 분기합니다.

- HEAD: 본문 없이 같은 상태/헤더를 반환
- OPTIONS: `Allow` 헤더로 허용 메서드를 알림
- 본문 없는 응답은 `$c->text('', $status)` 권장

## Routes

| Method  | Path  | Description |
|---------|-------|-------------|
| GET     | /api/ping | ping/pong |
| GET     | /api/healthz | k8s liveness |
| GET     | /api/readyz  | k8s readiness |
| GET     | /info | 정보(JSON) |
| HEAD    | /info | 동일 헤더, 빈 본문 |
| OPTIONS | /info | `Allow: GET, HEAD, OPTIONS`, 빈 본문 |

## 동작 방식 (왜 이렇게 될까)

### HEAD 는 "헤더만 확인하고 싶어"

HEAD 요청은 GET 과 **완전히 같은 응답 헤더**를 돌려주되, 본문은 보내지 않습니다.
클라이언트는 `ETag`/`Content-Length`/`Last-Modified` 등을 HEAD 로 확인한 뒤
실제 GET 을 할지 결정합니다.

```perl
if ($m eq 'HEAD') {
    $c->status(200);
    return $c->text('');
}
```

### OPTIONS 는 "이 리소스에 뭘 할 수 있지?"

CORS preflight 를 비롯해, 클라이언트는 OPTIONS 로 허용 메서드와 헤더를 미리 확인할
수 있습니다. 여기서는 `Allow` 헤더로 명시합니다.

```perl
if ($m eq 'OPTIONS') {
    $c->header('Allow' => 'GET, HEAD, OPTIONS');
    return $c->text('');
}
```

### 하나의 핸들러로 묶기

`any '/info'` 로 모든 메서드를 받으면, 메서드 분기가 명확하고 중복이 줄어듭니다.
(0.04 에서는 `head`/`options` 키워드가 따로 내장되지 않아 `any`+`req->method` 로 처리하는
것이 가장 안전합니다.)

## Notes

- 테스트는 GET 본문 유무, HEAD 빈 본문, OPTIONS `Allow` 헤더를 검증합니다.
