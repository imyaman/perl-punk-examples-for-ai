# Example 94 - 슬라이딩 윈도우 레이트 리밋 (Punk + Perl)

**고정 창의 경계 버그 없이** 요청 빈도를 제한하는 슬라이딩 윈도우(로그) 방식 예제입니다.

- `GET /api/hit` → 최근 `window` 초 안의 호출 수로 제한
- 초과 시 `429` + `Retry-After`
- `X-RateLimit-Limit / -Remaining / -Reset` 헤더로 상태 제공
- `PUT /ratelimit` 로 창/한도 설정

## Routes

| Method | Path          | Description |
|--------|---------------|-------------|
| GET    | /api/ping     | ping/pong |
| GET    | /api/hit      | 계량 대상 (`X-API-Key`) |
| GET    | /ratelimit    | 현재 설정 |
| PUT    | /ratelimit    | 창/한도 변경 |

## 동작 방식 (왜 이렇게 될까)

### 고정 창의 문제

"1분에 100회"를 **고정 창**(매분 0초 리셋)으로 세면, 0:59 에 100회 + 1:00 에 100회 =
**2초 동안 200회**가 통과합니다. 경계에서 몰립니다.

### 슬라이딩 윈도우 로그

요청 시각을 저장하고, **항상 최근 `window` 초만** 남겨 개수를 셉니다.

```perl
my $now = Time::HiRes::time();
my $edge = $now - $WINDOW;
@$log = grep { $_ > $edge } @$log;      # 오래된 것 제거
return 429 if @$log >= $LIMIT;
push @$log, $now;
```

### `Retry-After` 계산

가장 오래된 요청이 창을 벗어날 때까지 남은 시간이 곧 재시도 가능 시각입니다.

```perl
my $retry = $log->[0] + $WINDOW - $now;
```

### 메모리

로그는 매 요청마다 **가지치기**되어, 최대 `LIMIT` 개로 유지됩니다.

### 정밀도

`Time::HiRes` 를 써서 초 단위 경계를 부드럽게 처리하고, 테스트에서 짧은 창(2초)을
재현합니다.

## Notes

- 슬라이딩 윈도우 로그는 정확하지만 키가 많으면 메모리를 씁니다. 대안으로 **슬라이딩
  카운터**(이전/현재 창 가중 평균), **토큰 버킷**이 있습니다.
- 실전은 Redis `INCR`+`EXPIRE` 또는 Lua 스크립트로 원자 처리합니다.
- 테스트는 허용/초과/키 독립/창 이동/검증을 확인합니다.
