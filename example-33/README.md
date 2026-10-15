# Example 33 - 리다이렉트 상태 코드 (301/302/303/307/308) (Punk + Perl)

`$c->redirect($url, $code)` 로 리다이렉트 응답을 만드는 예제입니다. 상태 코드별
의미 차이를 함께 확인합니다.

- `$c->redirect('/target')` — 기본 302
- `$c->redirect('/target', 307)` — 코드 지정
- `Location` 헤더 자동 설정

## Routes

| Method | Path               | Description |
|--------|--------------------|-------------|
| GET    | /api/ping          | ping/pong |
| GET    | /api/healthz       | k8s liveness |
| GET    | /api/readyz        | k8s readiness |
| GET    | /redirect/default  | 302 로 /target |
| GET    | /redirect/301      | 301 로 /target |
| GET    | /redirect/302      | 302 로 /target |
| GET    | /redirect/303      | 303 로 /target |
| GET    | /redirect/307      | 307 로 /target |
| GET    | /redirect/308      | 308 로 /target |
| GET    | /target            | 도착지(JSON) |

## 동작 방식 (왜 이렇게 될까)

### 상태 코드는 "영구 vs 일시" 그리고 "메서드 보존 vs 변경"

| 코드 | 의미 | 메서드 |
|------|------|--------|
| 301 | 영구 이동 | GET 으로 바뀔 수 있음 |
| 302 | 임시 이동(전통) | 관행상 GET 으로 바뀜 |
| 303 | See Other | **항상 GET** 으로 |
| 307 | 임시 이동 | **원래 메서드 유지** |
| 308 | 영구 이동 | **원래 메서드 유지** |

301/302 는 역사적으로 클라이언트가 POST 를 GET 으로 바꾸는 일이 많았습니다. 이를
명확히 하려고 303(무조건 GET), 307/308(메서드·본문 보존)이 등장했습니다.

### POST 후 리다이렉트(PRG 패턴)

폼 제출 후 새로고침 중복 전송을 막으려면 `303` 으로 GET 상세 페이지로 보내는
**Post/Redirect/Get** 패턴이 표준입니다. 반대로 API 에서 메서드를 보존해야 하면
`307`/`308` 을 씁니다.

### 라우트를 루프로 정의

```perl
for my $code (301, 302, 303, 307, 308) {
    get "/redirect/$code" => sub { $_[0]->redirect('/target', $code) };
}
```

`for my $code` 는 반복마다 새 렉시컬을 만들므로 각 클로저가 자기 `$code` 를 안전하게
캡처합니다.

## Notes

- 테스트는 각 코드의 상태와 `Location` 헤더, 기본값 302 를 검증합니다.
