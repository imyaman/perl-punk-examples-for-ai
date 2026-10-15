# Example 26 - 비동기: `timer` / `after` / `promise` / `await` (Punk + Perl)

워커를 붙잡지 않고 **나중에 응답**하는 비동기 패턴 예제입니다.

- `$c->timer($secs)` / `$c->after($secs)` — N초 뒤 정산되는 future
- `$c->promise` — 나중에 외부에서 settle 하는 pending future
- `$c->await($future)` — 명령형 탈출구(결과를 값으로)

## Routes

| Method | Path             | Description |
|--------|------------------|-------------|
| GET    | /api/ping        | ping/pong (즉시) |
| GET    | /api/healthz     | k8s liveness |
| GET    | /api/readyz      | k8s readiness |
| GET    | /async/timer     | 1초 뒤 응답 (`timer`) |
| GET    | /async/promise   | 1초 뒤 settle (`promise` + `after`) |
| GET    | /async/await     | `await` 로 future 결과를 값으로 |

## 동작 방식 (왜 이렇게 될까)

### 핸들러가 future 를 반환하면 요청이 파킹된다

Hyperman 워커에서 핸들러가 future(`then`/`on_done`/`get`)를 반환하면, Punk 는 그
요청을 **보류**하고 워커는 **다른 요청을 계속 처리**합니다. future 가 정산되면 그때
응답이 나갑니다. 그래서 "기다리는" 요청이 워커 용량을 차지하지 않습니다.

```perl
return $c->timer(1)->then(sub { $c->json({ ready => 1 }) });
```

### `timer` vs `after`

둘 다 N초 뒤 정산되는 future 입니다. 워커 위에서는 **이벤트 루프 타이머**,
루프 밖(테스트/스크립트)에서는 **sleep** 으로 자연스럽게 열화됩니다(느리지만
깨지지 않음).

### `promise` 는 외부 정산 지점

`$c->promise` 는 아직 결과가 없는 future 를 줍니다. 이걸 반환해 요청을 보류해 두고,
**다른 무엇이 깨어났을 때**(타이머, 아웃바운드 응답 등) `$p->done($resp)` 로
정산합니다. 콜백 지옥 없이 "응답을 나중에 완성"하는 표준 방법입니다.

### `await` 는 탈출구

`$c->await($future)` 는 future 가 준비될 때까지 기다렸다가 **값을 반환**합니다.
명령형 코드가 편할 때 쓰지만, 워커를 그 시간 동안 점유하므로 남용하지 않습니다.
비동기 기본형은 `return $future` 입니다.

## Notes

- 테스트는 각 엔드포인트의 지연이 약 1초인지 시간 측정으로 검증합니다.
