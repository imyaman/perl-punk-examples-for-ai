# Example 98 - W3C traceparent 전파 (Punk + Perl)

W3C Trace Context 의 `traceparent` 헤더를 **이어받거나 새로 시작**해, 요청이 서비스들을
거쳐가도 하나의 트레이스로 묶이게 하는 예제입니다.

- `GET /traced` → `traceparent` 를 파싱/생성, 응답 헤더와 본문에 반영
- 없거나 잘못되면 새 트레이스 시작(`restarted`)
- 샘플링 플래그 유지

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /traced      | traceparent 처리 |

## 동작 방식 (왜 이렇게 될까)

### traceparent 형식

```
00-<32hex trace-id>-<16hex parent-id>-<2hex flags>
```

앞의 `00` 은 버전, 마지막 `01`/`00` 은 **샘플링** 플래그입니다.

```perl
/^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})$/i
```

### 이어받기 vs 새로 시작

유효한 헤더가 오면 그 `trace-id` 를 유지하고, **내 span-id 를 새로 만들어** 다음 홉으로
넘깁니다.

```perl
my $span_id = _gen(16);
my $out = "00-$ctx->{trace_id}-$span_id-" . ($ctx->{sampled} ? '01' : '00');
$c->header('traceparent' => $out);
```

### all-zero / 버전 불일치는 재시작

`trace-id` 나 `parent-id` 가 전부 0 이거나 버전이 `00` 이 아니면 **무효**로 보고 새
트레이스를 시작합니다. 그래야 깨진 값을 전파하지 않습니다.

### 샘플링 플래그 유지

`01` 이면 이 요청은 수집 대상입니다. 하위 서비스도 같은 플래그를 이어받아 **일관되게**
수집/미수집을 결정합니다.

### 왜 필요한가

분산 환경에서 로그/메트릭/트레이스를 **하나의 상관관계 ID**(trace-id)로 묶으려면 모든 홉이
표준 헤더를 전파해야 합니다. 상관관계 ID(예제 93)가 "이 서버 안"이라면, traceparent 는
"서비스 너머"로 이어집니다.

## Notes

- `tracestate` 헤더로 벤더별 상태도 전파할 수 있습니다.
- 실제로는 이 span-id 를 트레이싱 백엔드(OTel 등)에 보고합니다.
- 테스트는 생성/전파/샘플링/무효 재시작을 검증합니다.
