# Example 99 - 기능 플래그 (Feature Flags) (Punk + Perl)

플래그를 켜고 끄거나, **일부 사용자에게만 비율로** 노출하거나, 특정 키를 강제로 지정하는
예제입니다.

- `GET /flags/:name?key=` → 평가 결과 (`enabled`, `reason`)
- `PUT /flags/:name` → `enabled` / `rollout`(0..100) 설정
- `POST /flags/:name/override` → 특정 키 강제 on/off
- 우선순위: **override > enabled+rollout**

## Routes

| Method | Path                   | Description |
|--------|------------------------|-------------|
| GET    | /api/ping              | ping/pong |
| GET    | /flags/:name           | 플래그 평가 |
| GET    | /flags                | 목록 |
| PUT    | /flags/:name           | 설정 |
| POST   | /flags/:name/override  | 개별 키 강제 |

## 동작 방식 (왜 이렇게 될까)

### 안정적 버킷팅(bucketing)

같은 사용자는 **항상 같은 결과**를 받아야 합니다. 이름과 키를 해시해 0..99 로 매핑하면,
`rollout` 비율과 비교만 하면 됩니다.

```perl
sub _bucket { my ($name, $key) = @_; return hex(substr(sha1_hex("$name|$key"), 0, 4)) % 100 }
my $on = _bucket($name, $key) < $flag->{rollout};
```

### 왜 해시인가

`rand()` 로 매번 결정하면 사용자가 새로고침할 때마다 UI 가 바뀝니다. **안정적 버킷팅**은
같은 사용자를 항상 같은 그룹에 넣어 일관된 경험을 줍니다.

### override 우선

QA/내부 사용자에게는 비율과 무관하게 켜거나 끕니다. 평가 순서는 override → enabled →
rollout 입니다.

```perl
if (exists $flag->{overrides}{$key}) { return ($flag->{overrides}{$key}, 'override') }
```

### `reason` 을 함께 준다

왜 켜졌는지(`override`/`rollout`/`not_in_rollout`/`disabled`) 알려주면 디버깅이 쉽습니다.

### 비율 배포

`rollout` 을 0 → 10 → 50 → 100 으로 올리며 **카나리** 배포합니다.

## Notes

- 실전은 플래그를 외부 스토어(DB/서비스)에 두고 캐시합니다.
- `enabled=false` 는 rollout 을 무시하고 끕니다(킬 스위치).
- 테스트는 전체/0%/50% 분산/결정성/override/검증을 확인합니다.
