# Example 72 - CSV 내보내기 (Punk + Perl)

JSON API 를 **CSV 다운로드**로도 제공하는 예제입니다. 엑셀/스프레드시트 연동이나 대량
추출에 쓰입니다.

- `Content-Type: text/csv; charset=utf-8`
- `Content-Disposition: attachment; filename="users.csv"`
- 콤마/따옴표/줄바꿈이 있는 필드는 규칙대로 인용

## Routes

| Method | Path         | Description |
|--------|--------------|-------------|
| GET    | /api/ping    | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| GET    | /users       | JSON 목록 |
| GET    | /export.csv  | CSV 다운로드 |

## 동작 방식 (왜 이렇게 될까)

### 같은 데이터, 다른 표현

`/users` 는 JSON, `/export.csv` 는 CSV. 자원은 하나지만 **표현(representation)** 이
다릅니다. `Content-Disposition: attachment` 는 브라우저가 다운로드로 처리하게 합니다.

### CSV 이스케이프 규칙

RFC 4180 규칙:
- 필드에 `,` `"` 개행이 있으면 **큰따옴표로 감쌈**
- 내부 `"` 는 `""` 로 이중화

```perl
if ($v =~ /[",\r\n]/) {
    $v =~ s/"/""/g;
    return qq{"$v"};
}
```

이걸 안 하면 `Bob, Jr` 같은 값이 **열을 밀어** 데이터가 깨집니다.

### charset 명시

한글이 섞이면 `text/csv; charset=utf-8` 로 인코딩을 알려 주어야 엑셀에서 안 깨집니다.

### 개행

행 구분은 `\n` 을 사용했습니다. 윈도우 호환을 원하면 `\r\n` 을 쓸 수 있습니다.

## Notes

- 테스트는 헤더, 헤더행, 인용 규칙을 검증합니다.
