# Example 55 - Prefer 헤더 (return=minimal / representation) (Punk + Perl)

생성(POST) 응답에서 클라이언트가 **본문을 받을지/생략할지**를 고르게 하는 예제입니다.

- 기본: `201` + 생성된 표현(representation)
- `Prefer: return=minimal` → `201` + 빈 본문(+ `Location`)
- 응답에 `Preference-Applied` 로 실제 적용된 선호를 알림

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| POST   | /items      | `Prefer` 에 따라 본문 유무 |
| GET    | /items/:id  | 생성 확인용 조회 |

## 동작 방식 (왜 이렇게 될까)

### Prefer 는 "선호"지 "강제"가 아니다

`Prefer` 는 클라이언트의 **바람**을 전달합니다. 서버가 들어줄 수도, 못 들어줄 수도
있습니다. 들어줬으면 `Preference-Applied` 로 알려 줍니다. (표준 동작: `RFC 7240`)

```perl
if ($prefer =~ /return\s*=\s*minimal/i) {
    $c->header('Preference-Applied' => 'return=minimal');
    return $c->text('', 201);
}
```

### 왜 minimal 이 유용한가

대량 생성/모바일 등에서 결과 본문이 필요 없을 때 전송량을 줄일 수 있습니다.
`Location` 헤더만 있으면 이후 필요할 때 조회하면 됩니다.

### Location 은 항상 유지

본문을 생략해도 새로 만든 리소스의 위치(`Location`)는 반드시 남깁니다. 그래야
클라이언트가 결과를 찾아갈 수 있습니다.

## Notes

- 테스트는 기본 representation, minimal 빈 본문, `Preference-Applied`, Location 및 저장
  여부를 검증합니다.
