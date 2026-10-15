# Example 64 - 요청 본문 크기 제한 (413) (Punk + Perl)

과도하게 큰 요청 본문을 **413 Payload Too Large** 로 거절하는 예제입니다. `Content-Length`
로 선제 차단하고, 없으면(chunked) 실제 길이로 재확인합니다.

- `Content-Length > 1024` → 즉시 `413`
- `Content-Length` 없음 → 본문 길이로 판정
- 정상 → 파싱 후 반영, 깨진 JSON → `400`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| POST   | /submit     | 1KiB 초과 시 413 |

## 동작 방식 (왜 이렇게 될까)

### DoS 방어

크기 제한 없이 본문을 다 읽으면 메모리/디스크가 고갈될 수 있습니다. 상한을 두고 초과 시
일찍 끊습니다.

### 두 단계 검사

1. **Content-Length 선제 검사** — 본문을 읽기 전에 거절 (효율)
2. **실제 본문 길이 검사** — `Transfer-Encoding: chunked` 처럼 `Content-Length` 가 없거나
   거짓일 수 있으므로 확인

```perl
my $cl = $c->req->header('content-length');
if (defined $cl && $cl =~ /^\d+$/ && $cl > $MAX_BYTES) {
    return _too_large($c, $cl);
}
my $body = $c->req->body // '';
return _too_large($c, length $body) if length($body) > $MAX_BYTES;
```

### 413 vs 400

크기 초과는 `413`, 내용이 깨졌으면 `400` 으로 구분합니다.

## Notes

- 테스트는 정상/근접/초과/chunked 초과/깨진 JSON 을 검증합니다.
