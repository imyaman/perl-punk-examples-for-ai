# Example 65 - 서명된 만료 다운로드 링크 (Punk + Perl)

로그인 없이도 **서명 + 만료 시간**으로 보호되는 일회성 다운로드 URL 을 발급하는
예제입니다. S3 pre-signed URL 과 같은 개념입니다.

- `POST /links` → `/dl/<name>?exp=<epoch>&sig=<hmac>` 발급
- 서명 불일치 → `403`
- 만료 → `410 Gone`
- 파일 없음 → `404`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| POST   | /links      | 서명 링크 발급 |
| GET    | /dl/:name   | exp/sig 검증 후 전송 |

## 동작 방식 (왜 이렇게 될까)

### 왜 서명인가

파일을 공개 URL 로 두면 누구나 받습니다. 공유 비밀키로 **(파일명+만료)에 서명**해, URL
을 가진 사람만 일정 시간 동안 받을 수 있게 합니다.

```perl
sub _sign { hmac_sha256_hex("$name|$exp", $SECRET) }
```

### 만료 검사

`exp < now` 이면 `410 Gone` 을 돌려줍니다. 시각을 URL 에 넣기 때문에 서버에 상태를 둘
필요가 없습니다(stateless).

### 상수 시간 비교

서명 비교 역시 타이밍 공격을 피하려고 XOR 누적 비교를 씁니다.

### TTL 클램프

`ttl` 을 1초~24시간으로 제한해, 무한정 유효한 링크가 발급되지 않게 합니다.

## Notes

- 테스트는 생성/다운로드/위조 403/서명 누락 403/만료 410 을 검증합니다.
