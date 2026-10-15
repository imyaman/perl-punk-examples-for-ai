# Example 10 - `mount` 로 PSGI 서브앱 붙이기 (Punk + Perl)

Punk 라우트가 아닌 **순수 PSGI 앱**을 특정 접두사 아래에 마운트하는 예제입니다.
기존 PSGI 애플리케이션을 URL 한 구역에 그대로 끼워 넣을 때 씁니다.

- `mount '/legacy' => $psgi_app` — 접두사 아래에 PSGI 앱 위임
- 마운트된 앱은 **접두사가 제거된 PATH_INFO** 를 받음
- 가장 긴 접두사가 이김(longest prefix wins)

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| ANY    | /legacy/*       | 마운트된 순수 PSGI 앱으로 위임 |

## 응답 예

```json
GET /legacy/hello
-> {"legacy":1,"method":"GET","path":"/hello","script":"/legacy"}
```

## 동작 방식 (왜 이렇게 될까)

### Punk 앱도 결국 PSGI 앱이다

`to_app` 이 돌려주는 것은 PSGI coderef 입니다. 그래서 Punk는 **다른 PSGI 앱도
자기 라우팅의 한 구역에 붙일 수 있습니다**. `mount '/legacy' => $app` 는
`/legacy` 로 시작하는 요청을 그 앱에 넘깁니다.

### PATH_INFO / SCRIPT_NAME 규약

PSGI에서 마운트는 환경 변수로 표현됩니다.

- `SCRIPT_NAME` — 마운트된 접두사(`/legacy`)
- `PATH_INFO` — 접두사를 뗀 나머지(`/hello`)

그래서 `GET /legacy/hello` 가 마운트된 앱에는 `PATH_INFO = /hello` 로 도착합니다.
서브앱은 자기 경로를 상대적으로 다룰 수 있습니다.

### Punk 라우트와 공존

마운트 구역 밖의 경로(`/api/ping`)는 평소처럼 Punk 라우트가 처리합니다.
두 세계가 한 서버에서 공존하며, 접두사가 겹치면 더 긴 쪽이 우선합니다.

### 언제 쓰나

기존 Plack 앱, 다른 프레임워크 앱, 정적 생성기 산출물 등 "고칠 수 없거나 고치고
싶지 않은" PSGI 앱을 `/v2` 같은 구역에 그대로 얹을 때 유용합니다.

## Notes

- 마운트된 앱은 예제용 최소 PSGI 앱으로, JSON 을 직접 만들어 반환합니다.
