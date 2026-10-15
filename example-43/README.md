# Example 43 - Idempotency-Key (Punk + Perl)

`Idempotency-Key` 헤더를 받아 **동일한 요청의 중복 실행을 캐시된 응답으로 재생**하는
예제입니다. 결제/주문 같은 "한 번만 수행되어야 하는" 작업에 유용합니다.

- 헤더 `Idempotency-Key` 필수(없으면 400)
- 최초 요청: 실제 생성 후 캐시에 저장 → 201 + `Idempotent-Replayed: false`
- 동일 키 재전송: 캐시에서 재생 → 같은 상태코드/본문 + `Idempotent-Replayed: true`
- 다른 키: 새로 생성

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| POST   | /charge   | `Idempotency-Key` 헤더 필수; 중복시 재생 |

## 동작 방식 (왜 이렇게 될까)

### 멱등성(Idempotency)이란

네트워크 오류로 클라이언트가 재시도해도, **결과적으로 리소스 상태는 한 번만 변경**되도록
하는 개념입니다. 생성 API 의 경우 "같은 키로 두 번 POST 해도 1건만 생성"이 이상적입니다.

### 캐시 키 = Idempotency-Key

서버는 `(메서드 + 경로 + Idempotency-Key + 핵심본문)` 정도를 키로 삼기도 하지만,
여기서는 단순화해 **Idempotency-Key 단독**으로 캐시합니다.

```perl
if (exists $CACHE{$key}) {
    my $cached = $CACHE{$key};
    $c->header('Idempotent-Replayed' => 'true');
    return $c->json($cached->{body}, $cached->{status});
}
# 최초 생성 후 캐시 저장
```

### 재생 여부를 명확히 알리기

`Idempotent-Replayed` 같은 헤더로 "실제 실행 vs 캐시 재생"을 클라이언트에게 알려 주는
것도 실무에서 흔히 씁니다.

### 제약

- 이 예제의 캐시는 **프로세스 메모리**에 저장됩니다(재시작 시 초기화).
- 동시 요청(레이스 컨디션)은 고려하지 않았습니다.
- 생성 응답 전체(상태/본문/Location 등)를 캐시해 재생합니다.

## Notes

- 테스트는 키 누락 400, 최초 생성, 재생 검증, 다른 키 새 생성 등을 체크합니다.
