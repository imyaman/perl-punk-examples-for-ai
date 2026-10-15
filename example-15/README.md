# Example 15 - `plugin` 으로 기능 묶어 재사용 (Punk + Perl)

헬퍼·훅 같은 기능을 **플러그인 한 덩어리**로 묶어 `plugin` 한 줄로 설치하는
예제입니다. 여기서는 `Punk::Plugin::RequestId` 가 request id 헬퍼와
`before_dispatch` 훅을 함께 등록합니다.

- `plugin 'RequestId' => { prefix => 'rid' }` — 플러그인 로드
- 플러그인은 `Punk::Plugin` 을 상속하고 `register($app, $opts)` 를 구현
- `$app->helper(...)`, `$app->hook(...)` 로 앱에 기능 설치

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/whoami     | 플러그인이 부여한 request id |

## 구성

```
lib/Daeha.pm                        앱 (plugin 'RequestId' 한 줄)
lib/Punk/Plugin/RequestId.pm        플러그인 (헬퍼 + 훅)
```

## 동작 방식 (왜 이렇게 될까)

### 플러그인 = 등록 시점에 앱을 만지는 객체

`plugin 'RequestId'` 는 `Punk::Plugin::RequestId` 를 찾아 인스턴스화하고,
그 `register($self, $app, \%opts)` 를 **앱 등록 시점**에 한 번 호출합니다.
`$app` 는 DSL 키워드가 쓰는 것과 같은 등록 표면(registrar)이라, 플러그인은
앱이 할 수 있는 일(라우트·스코프·훅·미들웨어·on_error·헬퍼)을 전부 할 수 있습니다.

### 이 예제의 플러그인이 하는 일

1. `$app->helper(request_id => sub { ... })` — `$c->request_id` 메서드 설치
2. `$app->hook(before_dispatch => sub { ... })` — 요청마다 id 부여

`register` 는 요청마다가 아니라 **부팅 시 한 번** 돕니다. 요청마다 도는 건 그 안에
등록한 훅입니다.

### 헬퍼 이름 충돌은 부팅 시 검출

플러그인이 설치하는 헬퍼 이름이 코어 `Punk::Context` 메서드나 다른 헬퍼와 겹치면
**부팅 시점에 croak** 합니다(런타임 조용한 덮어쓰기 없음). 그래서 이름이 중요합니다.

### 플러그인 vs 헬퍼 직접 등록

기능이 하나면 예제 14처럼 `helper` 만 써도 됩니다. 하지만 **헬퍼 + 훅 + 라우트 +
설정**이 한 세트로 묶이는 순간, 그 세트를 플러그인으로 만들면 다른 앱에서
`plugin` 한 줄로 재사용할 수 있습니다.

## Notes

- `plugin '+Full::Class'` 형태로 네임스페이스 없이 클래스를 직접 지정할 수도 있습니다.
- `prefix` 옵션으로 id 접두사를 바꿀 수 있습니다.
