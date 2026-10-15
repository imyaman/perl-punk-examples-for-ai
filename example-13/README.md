# Example 13 - `on_error` 커스텀 에러 핸들러 (Punk + Perl)

핸들러나 가드가 `die` 했을 때 기본 500 대신 **직접 만든 에러 응답**을 돌려주는
예제입니다.

- `on_error sub { my ($c, $err) = @_; ... }`
- reference 를 반환하면 그것이 응답이 됨 (여기서는 500 JSON)
- 반환하지 않으면 Punk 기본 `500 {"errors":[...]}` 가 나감

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/ok         | 정상 200 |
| GET    | /api/boom       | `die` → on_error 가 500 JSON |

## 응답 예

```json
GET /api/boom
-> 500 {"error":{"code":"INTERNAL","message":"kaboom: something went wrong"}}
```

## 동작 방식 (왜 이렇게 될까)

### `die` 는 예외 전파 경로를 탄다

핸들러에서 `die` 하면 요청 처리가 중단되고, Punk는 이를 **에러 처리 경로**로
보냅니다. 이때 `on_error` 가 등록되어 있으면 `($c, $err)` 로 호출됩니다.

- **응답(reference)을 반환하면** 그 응답으로 마무리합니다.
- **아무것도 반환하지 않으면** Punk 기본값(500 `{"errors":[...]}`)이 나갑니다.

### 일관된 에러 스키마를 프레임워크 레벨에서

예제 3에서 핸들러마다 손으로 만들던 에러 바디를, 여기서는 `on_error` 한 곳에서
통일합니다. 예기치 못한 예외까지 같은 골격(`error.code`/`error.message`)으로
응답하게 됩니다.

### 노출에 주의

`$err` 를 그대로 메시지에 넣으면 내부 정보가 새어 나갈 수 있습니다. 운영에서는
로그에만 상세를 남기고 응답에는 일반화된 메시지를 쓰는 편이 안전합니다.

### 훅/미들웨어와의 위치

`on_error` 는 프레임워크 내부(가드·핸들러 die)를 담당합니다. `after_dispatch`
(예제 11)는 정상 흐름의 응답을, `middleware`(예제 12)는 최외곽을 담당합니다.

## Notes

- `on_error` 는 예외를 잡는 지점이라, 응답 본문에 예외 문자열이 포함됩니다(예제용).
