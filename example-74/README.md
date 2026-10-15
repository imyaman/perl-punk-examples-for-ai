# Example 74 - 소프트 삭제와 복구 (Punk + Perl)

행을 실제로 지우지 않고 **삭제 표시(deleted_at)** 만 남겨 복구 가능하게 하는 예제입니다.

- `DELETE /items/:id` → 소프트 삭제(`deleted_at` 기록)
- 기본 조회/목록에서 숨김
- `?include_deleted=1` / `?only_deleted=1` 로 조회
- `POST /items/:id/restore` → 복구
- 이미 복구된 항목 복구 시도 → `409`

## Routes

| Method | Path                 | Description |
|--------|----------------------|-------------|
| GET    | /api/ping            | ping/pong |
| GET    | /api/healthz         | k8s liveness |
| GET    | /api/readyz          | k8s readiness |
| POST   | /items               | 생성 |
| GET    | /items               | 목록(필터) |
| GET    | /items/:id           | 단건 |
| DELETE | /items/:id           | 소프트 삭제 |
| POST   | /items/:id/restore   | 복구 |

## 동작 방식 (왜 이렇게 될까)

### 왜 소프트 삭제인가

실수로 지운 데이터 복구, 감사 로그, 참조 무결성 유지에 유리합니다. 하드 삭제는 되돌릴 수
없습니다.

### 조회에서 숨기되 데이터는 남긴다

기본 조회는 `deleted_at` 이 있는 행을 제외합니다.

```perl
else { push @out, _view($it) unless $it->{deleted_at} }
```

`include_deleted`/`only_deleted` 로 관리자/감사 용도로 노출합니다.

### 삭제도 멱등/명확하게

이미 삭제된 항목을 다시 지우면 `404`, 삭제된 항목이 아니면 복구는 `409` 로 상태를
정확히 알려 줍니다.

### 실제 삭제와의 차이

- 하드 삭제: `DELETE` → `204`, 이후 `GET` `404`
- 소프트 삭제: 겉보기엔 같지만 데이터가 남아 복구 가능

## Notes

- 메모리 기반이라 재시작 시 초기화됩니다.
- 테스트는 삭제/숨김/필터/복구/409/404 를 검증합니다.
