# Example 70 - Cache-Control 정책 (Punk + Perl)

리소스 성격에 따라 **캐시 정책**을 다르게 주는 예제입니다. 공개/비공개/재검증/장기
불변 등 대표 패턴을 보여줍니다.

- `public, max-age=3600` (+ `Expires`)
- `private, no-store`
- `no-cache, max-age=0, must-revalidate`
- `public, max-age=60, stale-while-revalidate=30`
- `public, max-age=31536000, immutable`

## Routes

| Method | Path          | Description |
|--------|---------------|-------------|
| GET    | /api/ping     | ping/pong |
| GET    | /api/healthz  | k8s liveness |
| GET    | /api/readyz   | k8s readiness |
| GET    | /cache/:kind  | 정책별 Cache-Control |

## 동작 방식 (왜 이렇게 될까)

### 캐시 정책은 "누가"와 "얼마나"의 문제

- `public` : 공유 캐시(CDN)도 저장 가능
- `private`: 브라우저만 저장 (사용자별 데이터)
- `no-store`: 아예 저장 금지 (민감 정보)

### no-cache 는 "캐시 금지"가 아니다

`no-cache` 는 **저장은 하되 매번 재검증**하라는 뜻입니다. 진짜 금지는 `no-store`
입니다. `must-revalidate` 는 만료 후 반드시 재검증을 강제합니다.

### stale-while-revalidate

만료 후에도 `stale-while-revalidate=30` 초 동안은 **오래된 응답을 즉시 주면서** 백그라운드
에서 갱신합니다. 체감 속도가 크게 좋아집니다.

### immutable

내용이 절대 바뀌지 않는 자산(해시가 붙은 JS/CSS)에 `immutable` + 긴 `max-age` 를 주면
브라우저가 재검증조차 하지 않습니다.

### Expires 병행

`max-age` 를 모르는 아주 오래된 캐시를 위해 `Expires` 도 함께 넣습니다(구형 호환).

## Notes

- 테스트는 각 정책 헤더와 Expires 유무, 미지원 404 를 검증합니다.
