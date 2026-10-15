# Example 62 - Last-Modified / If-Modified-Since (304) (Punk + Perl)

`ETag`(예제 32)와 짝을 이루는 **시간 기반 조건부 GET** 예제입니다. 클라이언트가 가진
사본의 시각을 보내면, 그 이후 변경이 없을 때 본문 없이 `304` 를 돌려줍니다.

- `GET /page` → `Last-Modified` 포함
- `If-Modified-Since` 가 최신이면 `304` (빈 본문)
- 그보다 과거면 `200` + 본문
- `PUT /page` 후 `Last-Modified` 갱신

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /page       | Last-Modified + 조건부 304 |
| PUT    | /page       | 내용 변경 |

## 동작 방식 (왜 이렇게 될까)

### ETag vs Last-Modified

- `ETag`: 내용 해시. 정확하지만 계산 비용이 듦
- `Last-Modified`: 수정 시각. 싸지만 **1초 해상도**라 같은 초에 두 번 바뀌면 놓칠 수 있음

둘 다 제공하면 클라이언트가 더 정밀한 조건을 쓸 수 있습니다.

### HTTP 날짜 파싱의 함정

`If-Modified-Since` 는 `Thu, 01 Jan 1970 00:00:00 GMT` 같은 **HTTP 날짜**입니다. 이걸
파싱할 때 `Time::Local` 의 2자리 연도 휴리스틱에 걸리면 `70` 이 1970 이 아니라 2070 으로
해석되는 문제가 있습니다. 그래서 여기서는 의존성 없이 **civil date → epoch** 변환을
직접 구현했습니다.

```perl
sub _days_from_civil {
    my ($y, $m, $d) = @_;
    $y -= ($m <= 2) ? 1 : 0;
    my $era = int(($y >= 0 ? $y : $y - 399) / 400);
    my $yoe = $y - $era * 400;
    my $doy = int((153 * ($m + (($m > 2) ? -3 : 9)) + 2) / 5) + $d - 1;
    my $doe = $yoe * 365 + int($yoe / 4) - int($yoe / 100) + $doy;
    return $era * 146097 + $doe - 719468;
}
```

### 비교 규칙

`If-Modified-Since >= Last-Modified` 이면 변경 없음으로 보고 `304` 를 돌려줍니다. 과거면
전체 본문을 다시 보냅니다.

### 304 에도 Last-Modified 유지

`304` 응답에도 `Last-Modified` 를 포함시키면 클라이언트가 다음 조건부 요청에 계속
사용할 수 있습니다.

## Notes

- 테스트는 최초 200, 304(같은 시각), 과거 시각 200, PUT 후 갱신/304 를 검증합니다.
