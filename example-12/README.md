# Example 12 - middleware (PSGI 래퍼) (Punk + Perl)

Punk 컨텍스트 **바깥**에서 요청/응답을 감싸는 PSGI 미들웨어를 시연하는 예제입니다.
여기서는 모든 응답에 처리시간(`X-Runtime-Ms`) 헤더를 붙입니다.

- `middleware sub { my ($app) = @_; sub { my ($env) = @_; ... } }`
- 미들웨어는 `to_app` 시점에 적용되어 **모든 요청**을 감쌈
- 응답은 PSGI 트리플릿 `[status, headers, body]`

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/work       | 일반 핸들러 (미들웨어가 감쌈) |

모든 응답에 `X-Runtime-Ms` 헤더가 붙습니다.

## 동작 방식 (왜 이렇게 될까)

### 미들웨어 = PSGI 앱을 받아 PSGI 앱을 돌려주는 함수

Punk 앱은 결국 하나의 PSGI coderef 입니다. `middleware` 는 그 앱을 인자로 받아
**새 PSGI 앱을 감싼 앱**을 반환합니다(Plack 스타일 팩토리).

```perl
middleware sub {
    my ($app)  = @_;               # 안쪽 PSGI 앱
    return sub {
        my ($env) = @_;            # 원시 PSGI 환경
        my $res = $app->($env);    # 안쪽 앱 호출
        ...                        # 전/후처리
        return $res;               # PSGI 트리플릿 반환
    };
};
```

### 훅과의 차이

- **훅**(예제 11)은 `$c`(Punk::Context)를 받습니다 → 라우팅/가드와 같은 층.
- **미들웨어**는 `$env`(원시 PSGI 환경)를 받습니다 → **가장 바깥** 층.
  Punk 컨텍스트가 만들어지기 전/사라진 뒤에도 손댈 수 있고, 라우팅되지 않는
  요청(404 포함)도 감쌉니다.

### 왜 PSGI 레벨이 유용한가

타이밍·로깅·압축·IP 신뢰 등 "프레임워크와 무관한" 처리는 PSGI 레벨이 맞습니다.
Punk를 쓰지 않는 다른 PSGI 앱에도 같은 미들웨어를 재사용할 수 있습니다.

## Notes

- 본문이 스트리밍(코드 ref)이면 헤더를 배열로 가정하지 않도록 방어적으로 처리합니다.
