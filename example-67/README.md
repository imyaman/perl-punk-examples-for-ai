# Example 67 - PUT 업서트 (생성 또는 대체) (Punk + Perl)

`PUT /users/:id` 한 번으로 **없으면 생성, 있으면 대체**하는 예제입니다. 클라이언트가
POST 와 PUT 을 구분하지 않고 `PUT` 하나만 쓰면 됩니다.

- 최초 PUT → `201 Created`
- 같은 id 다시 PUT → `200 OK` (대체)
- 검증 실패 → `422`
- 삭제 → `204`, 이후 조회 `404`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| PUT    | /users/:id  | 업서트 (201/200) |
| GET    | /users/:id  | 조회 |
| DELETE | /users/:id  | 삭제 (204) |

## 동작 방식 (왜 이렇게 될까)

### POST vs PUT vs PATCH

- `POST` : 생성 (id 미정 → 서버가 결정)
- `PUT` : 대체 (id 결정 → 전체 속성을 넣으면 업서트)
- `PATCH` : 일부 변경 (예제 50)

업서트를 `PUT` 으로 보면 멱등하게 재시도해도 결과가 같습니다.

```perl
my $exists = exists $USERS{$id};
$USERS{$id} = { id => $id, name => "$b->{name}", email => "$b->{email}" };
return $c->json($USERS{$id}, $exists ? 200 : 201);
```

### 검증은 422

대체 전에 반드시 검증합니다. 남는 값이 있는 것을 지우는 식으로 덮어쓸 수 있으므로,
검증 실패 시 **무시하고 저장하지 않는 것**이 안전합니다.

### Location 은 항상

`201`/`200` 모두 `Location` 을 준다 편이 클라이언트가 리소스 위치를 알기에 좋습니다.

## Notes

- 테스트는 201/200 전환, 영속성, 422, 400, 삭제 204/404 를 검증합니다.
