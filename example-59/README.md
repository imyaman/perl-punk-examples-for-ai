# Example 59 - 파일 기반 JSON 저장소 (DB 대체) (Punk + Perl)

DB 드라이버 없이 **JSON 파일**을 영속 저장소로 쓰는 예제입니다. 노트를 생성/조회/삭제
하고, 저장은 임시 파일 + `rename` 으로 **원자적으로** 교체합니다.

- `GET /notes` 목록
- `POST /notes` 생성 → `201` + `Location`
- `GET /notes/:id` 조회
- `DELETE /notes/:id` 삭제 → `204`
- 저장 위치: `$ENV{DAEHA_STORE} // /tmp/daeha-store.json`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /notes      | 목록 |
| POST   | /notes      | 생성 |
| GET    | /notes/:id  | 단건 조회 |
| DELETE | /notes/:id  | 삭제 |

## 동작 방식 (왜 이렇게 될까)

### 왜 파일인가

소규모/예제 수준에서는 외부 DB 없이도 데이터를 유지하고 싶을 때가 많습니다. JSON 파일
하나로 충분하며, 나중에 진짜 DB 로 바꿔도 **인터페이스(`_load`/`_save`)만 교체**하면
됩니다.

### 원자적 쓰기 (temp + rename)

파일에 직접 쓰다가 중간에 죽으면 파일이 깨집니다. **임시 파일에 쓰고 `rename`** 하면
같은 파일시스템 내에서 교체가 원자적이라, 독자는 항상 완전한 이전/이후 버전만 봅니다.

```perl
my $tmp = "$STORE.$$.tmp";
open(my $fh, '>', $tmp) or die $!;
print $fh $J->encode($d);
close $fh;
rename($tmp, $STORE) or die $!;   # 원자적 교체
```

### 깨진 파일 방어

`_load` 는 파일이 없거나 JSON 이 깨졌으면 기본값(`{seq,items}`)으로 복구합니다. 예외로
죽지 않고 서비스가 계속 동작하도록 합니다.

### 한계 (정직하게)

동시 쓰기(락)와 트랜잭션은 없습니다. 단일 프로세스/저빈도 예제에 적합하며, 동시성이
필요하면 DB 나 파일 락이 필요합니다.

## Notes

- 테스트는 초기화 후 생성/조회/목록/삭제/404/영속성을 검증합니다.
