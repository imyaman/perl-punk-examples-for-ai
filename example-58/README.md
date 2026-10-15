# Example 58 - Range 요청 / 206 Partial Content (Punk + Perl)

파일/콘텐츠의 **일부분만** 요청할 수 있게 하는 예제입니다. 다운로드 재개, 스트리밍,
대용량 파일 전송에 쓰입니다.

- `Range` 없음 → `200` 전체
- `bytes=0-9` → `206` + `Content-Range: bytes 0-9/200`
- `bytes=10-` (오픈) → 끝까지
- `bytes=-5` (서픽스) → 마지막 5바이트
- 처리 불가 범위 → `416` + `Content-Range: bytes */200`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /file       | Range 지원(200/206/416) |

## 동작 방식 (왜 이렇게 될까)

### Accept-Ranges 로 알린다

서버가 범위 요청을 지원하면 `Accept-Ranges: bytes` 를 응답에 넣어 클라이언트가
부분 요청을 시도할 수 있게 합니다.

### Range 문법 3가지

```
bytes=0-9     시작-끝
bytes=10-     시작부터 끝까지
bytes=-5      마지막 5바이트
```

정규식 `^bytes=(\d*)-(\d*)$` 로 파싱하면 세 경우를 구분할 수 있습니다.

### 416 Unsatisfied Range

요청 범위가 콘텐츠를 벗어나면 `416` 과 함께 `Content-Range: bytes */<길이>` 로
실제 크기를 알려 줍니다. 그래야 클라이언트가 올바른 범위로 재시도할 수 있습니다.

### Content-Range 형식

성공 시 `Content-Range: bytes <start>-<end>/<total>`, 실패 시 `bytes */<total>`.

## Notes

- 테스트는 전체 200, `0-9`, 오픈, 서픽스, 불가 범위 416 을 검증합니다.
