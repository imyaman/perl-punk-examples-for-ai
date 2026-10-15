# Example 76 - 콘텐츠 주소 저장소 (SHA-256) (Punk + Perl)

**내용의 SHA-256 을 id 로 삼아** 저장하는 예제입니다. 같은 내용은 자동으로 중복 제거되고,
id 가 곧 무결성 검증 수단이 됩니다.

- `POST /blobs` → 해시를 id 로 저장 (`201`)
- 같은 내용 재전송 → `200` + `deduplicated: 1`
- `GET /blobs/:id` → 내용 반환 (`ETag` 포함)
- `GET /blobs/:id/meta` → 크기/타입
- `If-None-Match` → `304`

## Routes

| Method | Path           | Description |
|--------|----------------|-------------|
| GET    | /api/ping      | ping/pong |
| GET    | /api/healthz   | k8s liveness |
| GET    | /api/readyz    | k8s readiness |
| POST   | /blobs         | 내용 저장 |
| GET    | /blobs/:id     | 내용 조회 |
| GET    | /blobs/:id/meta| 메타데이터 |

## 동작 방식 (왜 이렇게 될까)

### 주소가 곧 내용이다

id 를 랜덤 UUID 가 아니라 **본문 해시**로 정하면:

- **자연스러운 중복 제거** — 같은 내용은 같은 id
- **무결성 검증** — 받은 내용의 해시를 다시 계산하면 id 와 비교
- **내용 변경 없이는 안 변함** — 참조하는 쪽이 안정적

```perl
my $id = sha256_hex($data);
```

### 중복 처리 정책

처음 넣으면 `201`, 이미 있으면 `200` 과 `deduplicated: 1` 을 돌려줍니다. **실패는
아니므로** 오류로 처리하지 않습니다.

### ETag 도 같이

id 자체가 ETag 로 쓸 수 있어 조건부 GET(`If-None-Match` → `304`) 이 자연스럽습니다.

## Notes

- 메모리 기반이며, 실제로는 콘텐츠를 파일/객체 스토리에, id 만 해시 트리에 두면 됩니다.
- 테스트는 해시 id/중복/조회/304/메타/404/400 을 검증합니다.
