# Example 66 - Accept-Language 협상 (i18n) (Punk + Perl)

`Accept-Language` 헤더의 `q` 값 가중치를 해석해 **최적 언어**를 고르고, 캐시가 그에
맞게 캐시되도록 `Vary` 를 보내는 예제입니다.

- `en`(기본), `ko`, `ja`, `de` 지원
- `q` 값 우선순위, `ko-KR` → `ko` 하위태그 매칭, 불일치 시 기본값
- `?lang=` 로 오버라이드 가능
- 응답: `Content-Language`, `Vary: Accept-Language`

## Routes

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | /api/ping   | ping/pong |
| GET    | /api/healthz| k8s liveness |
| GET    | /api/readyz | k8s readiness |
| GET    | /greeting   | Accept-Language 협상 |

## 동작 방식 (왜 이렇게 될까)

### q 값 해석

`Accept-Language: ko;q=0.9, en;q=1.0` 을 `,` 로 나눠 **q 값 내림차순** 정렬한 뒤, 서버가
지원하는 언어를 찾습니다.

```perl
@prefs = sort { $b->[1] <=> $a->[1] } @prefs;
```

### 하위태그 매칭

`ko-KR` 처럼 서버에 없는 태그는 근본 언어(`ko`)를 대신 시도합니다. 그래도 없으면 기본값
`en` 으로 falls back 합니다.

```perl
my ($base) = split /-/, $tag;
return $base if exists $MSG{$base};
```

### Vary 로 캐시 분리

응답이 요청 헤더에 따라 달라지면 캐시가 헷갈립니다. `Vary: Accept-Language` 를 달면
프록시가 언어별로 **별도 캐시 엔트리**를 유지합니다.

### 쿼리 오버라이드

URL 파라미터(`?lang=ja`)는 링크로 공유할 때 강제 지정할 수 있으므로 헤더보다 높은
우선순위를 줬습니다. 지원하지 않는 값은 무시하고 협상으로 되돌립니다.

## Notes

- 테스트는 기본값/지정/`q` 우선/하위태그/미지원 fallback/오버라이드를 검증합니다.
- 비ASCII 비교를 위해 테스트는 `use utf8` + `Encode::decode_utf8` 를 함께 씁니다.
