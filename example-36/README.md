# Example 36 - 부분 필드 선택 (Sparse Fieldsets) (Punk + Perl)

`?fields=id,name` 처럼 원하는 필드만 요청해 응답 사이즈를 줄이는 예제입니다.

- 쿼리 파라미터 `fields` → 쉼표 구분
- 존재하지 않는 필드는 `400 Bad Request` 로 거절
- 허용된 필드 목록을 에러 응답에 포함

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /users/:id  | `?fields=...` 로 부분 응답 |

## 동작 방식 (왜 이렇게 될까)

### "어떤 필드를 줄까?"만 결정한다

클라이언트가 필요한 최소한의 필드만 고르면, 대형 객체를 반환할 때 전송량을 줄이고
네트워크 비용·렌더링 시간을 절감합니다. 특히 모바일 등 저대역폭에서 유용합니다.

```perl
return { data => { map { $_ => $USER{$_} } @want } };
```

### 요청 필드 검증

모든 요청 필드가 실제 필드 집합에 속하는지 먼저 검사합니다. 오타나 존재하지 않는
필드명을 그대로 내보내면 캐시/로직 혼란이 생길 수 있으므로 **명시적으로 400** 으로
거절합니다.

```perl
return $c->json({ error => "unknown field: $w", allowed => \@all }, 400)
    unless $valid{$w};
```

### 요청 순서는 유지하되, 응답 구조 선택은 자유

여기서는 요청한 순서대로 키를 순회해 하드셋 만들지만, 실제 JSON 직렬화 결과의
키 순서는 직렬라이저 설정과 무관하게 테스트 상에서는 키 유무 위주로 검증합니다.

## Notes

- 테스트는 전체/부분/순서 교차/미지정 필드 거절을 검증합니다.
