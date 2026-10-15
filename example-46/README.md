# Example 46 - 원시 바이트 응답 (Punk + Perl)

이미지 같은 **바이너리/원시 데이터**를 적절한 `Content-Type` 으로 내려주는 예제입니다.
`$c->text($bytes)` 로 원시 문자열을 그대로 반환합니다.

- `GET /images` — 목록
- `GET /images/:id` — 메타데이터(JSON)
- `GET /images/:id/raw` — 원시 바이트(`image/jpeg` 또는 `image/png`)
- `Cache-Control: public, max-age=60`

## Routes

| Method | Path             | Description |
|--------|------------------|-------------|
| GET    | /api/ping        | ping/pong |
| GET    | /api/healthz     | k8s liveness |
| GET    | /api/readyz      | k8s readiness |
| GET    | /images          | 이미지 메타 목록 |
| GET    | /images/:id      | 메타데이터 |
| GET    | /images/:id/raw  | 원시 바이트(`image/*`) |

## 동작 방식 (왜 이렇게 될까)

### 텍스트 응답으로 바이트를 그대로 보낸다

`$c->text($data)` 는 문자열을 본문으로 넣습니다. 바이너리도 Perl 문자열이므로 그대로
전달됩니다. 미리 `Content-Type` 과 `Content-Length` 를 지정합니다.

```perl
$c->header('Content-Type' => $ct);
$c->header('Content-Length' => length($img->{data}));
return $c->text($img->{data});
```

### 라우트 순서/구분자에 주의 (중요)

처음엔 `/images/:id.raw` 로 시도했는데 실패했습니다. `:id` 는 **한 세그먼트**를
잡으므로 `1.raw` 전체가 `id` 로 들어가고, 점(`.`)은 세그먼트 구분자가 아닙니다.
그래서 `/images/:id` 메타데이터 라우트가 먼저 매칭돼 JSON 이 나왔습니다.

이를 피하려고 **경로를 세그먼트로 분리**해 `/images/:id/raw` 로 정의했습니다. REST 에서
"확장자" 대신 하위 리소스로 원본을 노출하는 편이 라우터 모호성도 줄입니다.

### 캐싱

이미지는 잘 변하지 않으므로 `Cache-Control: public, max-age=60` 을 붙여 CDN/브라우저
캐시를 유도합니다. (예제 32 의 ETag 와 결합하면 더 좋습니다.)

## Notes

- 테스트는 메타데이터, 원시 바이트/`Content-Type`/`Content-Length`, 404 를 검증합니다.
