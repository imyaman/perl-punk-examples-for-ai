# Example 39 - REST CRUD + 201/204 (Punk + Perl)

간단한 인-메모리 KV 로 POST/GET/PUT/DELETE + 목록을 구현한 예제입니다. 상태 코드와
헤더를 REST 관례에 맞게 사용합니다.

- `POST` → `201 Created` + `Location` 헤더
- `PUT` → `200 OK` (전체 갱신)
- `DELETE` → `204 No Content` + 빈 본문
- 없는 리소스 → `404 Not Found`
- 필수값 누락 → `400 Bad Request` (RFC 7807)

## Routes

| Method | Path      | Description |
|--------|-----------|-------------|
| GET    | /api/ping | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| POST   | /kv/:key  | `{value:...}` 저장 → 201 + Location |
| GET    | /kv/:key  | 조회 → 200 또는 404 |
| PUT    | /kv/:key  | `{value:...}` 갱신 → 200 |
| DELETE | /kv/:key  | 삭제 → 204 또는 404 |
| GET    | /kv       | 전체 목록 |

## 동작 방식 (왜 이렇게 될까)

### POST = 생성, 201 + Location

새 리소스를 만들면 `201 Created` 와 생성된 리소스 위치를 `Location` 헤더로 반환합니다.
클라이언트는 이 Location 을 따라 즉시 GET 할 수 있습니다.

```perl
$KV{$key} = $val;
$c->header('Location' => "/kv/$key");
return $c->json({ key => $key, value => $KV{$key} }, 201);
```

### DELETE = 성공 시 204 (본문 없음)

삭제 성공 시 `200` 이 아니라 **`204 No Content`** 가 관례적입니다. 본문이 없기에
`text('', 204)` 로 빈 응답을 보냅니다.

```perl
delete $KV{$key};
return $c->text('', 204);
```

### 에러는 Problem Details 로 일관되게

누락된 필드나 존재하지 않는 키는 예제 38 과 같은 `application/problem+json` 형식으로
반환합니다. `instance` 에 요청 경로를 포함해 추적성을 높입니다.

### PUT 은 전체 교체

여기서 PUT 은 전체 갱신을 의미합니다(부분 갱신은 PATCH). 단순함을 위해 `value` 전체를
덮어씁니다.

## Notes

- 데이터는 프로세스 메모리에만 저장됩니다(서버 재시작 시 초기화).
- 테스트는 생성/조회/갱신/목록/삭제/미존재 케이스를 검증합니다.
