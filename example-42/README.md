# Example 42 - X-HTTP-Method-Override (Punk + Perl)

클라이언트(특히 구형 폼이나 일부 프록시)가 `PUT/PATCH/DELETE` 같은 메서드를 직접
보내기 어려울 때, `POST` 로 요청하고 `X-HTTP-Method-Override` 헤더로 실제 메서드를
지시하는 패턴입니다.

- 헤더 `X-HTTP-Method-Override` 가 있으면 그 값을 실제 메서드로 간주
- 지원: `PUT`, `PATCH`, `DELETE` (여기서는 표현 목적)
- 헤더가 없으면 원래 메서드 유지

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| ANY    | /override | 헤더로 메서드 오버라이드(POST+헤더로 PUT/PATCH/DELETE) |

## 동작 방식 (왜 이렇게 될까)

### 왜 필요할까

HTML 폼(`<form method="POST">`)은 GET/POST 만 지원합니다. REST 에서 PUT/PATCH/DELETE 를
쓰고 싶으면, 폼에서는 POST 를 보내고 숨김필드 `_method` 나 헤더 `X-HTTP-Method-Override`
로 실제 의도를 전달합니다. 많은 웹 프레임워크가 이 패턴을 지원합니다.

```perl
my $m = $c->req->header('x-http-method-override') // $c->req->method;
$m = uc($m);
if ($m eq 'PATCH') { ... }
```

### 보안상 주의

헤더를 신뢰하면, CSRF/프록시 환경에서 오해를 부를 수 있습니다. 일반적으로 **같은 출처
요청**이거나 신뢰 가능한 프록시 경유일 때만 허용하는 식으로 제한합니다. 이 예제는
학습용으로 단순화했습니다.

## Notes

- 테스트는 POST 기본값, POST+헤더에 의한 PUT/PATCH/DELETE 오버라이드를 검증합니다.
