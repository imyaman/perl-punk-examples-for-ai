# Example 73 - JWT (HS256) 발급/검증 (Punk + Perl)

외부 라이브러리 없이 **HMAC-SHA256 JWT**를 발급하고 검증하는 예제입니다. 최소 구현으로
토큰 구조(header.payload.signature)를 이해하기 좋습니다.

- `POST /auth/login` → HS256 JWT 발급
- `GET /me` → `Authorization: Bearer <jwt>` 검증
- 서명 위조/변조/만료 → `401`

## Routes

| Method | Path          | Description |
|--------|---------------|-------------|
| GET    | /api/ping     | ping/pong |
| GET    | /api/healthz  | k8s liveness |
| GET    | /api/readyz   | k8s readiness |
| POST   | /auth/login   | JWT 발급 |
| GET    | /me           | Bearer 검증 |

## 동작 방식 (왜 이렇게 될까)

### JWT 구조

`base64url(header).base64url(payload).base64url(signature)` 3조각으로, 서명은 앞 두
조각을 `SECRET` 으로 HMAC-SHA256 한 값입니다.

```perl
my $input = _b64($header) . '.' . _b64($payload);
my $sig   = _b64(hmac_sha256($input, $SECRET));
```

### Base64URL

JWT 는 URL/헤더에서 안전하도록 표준 base64 의 `+` `/` `=` 를 `-` `_` 와 생략으로 바꾼
**base64url** 을 씁니다. `MIME::Base64::encode_base64url` 이 이를 처리합니다.

### 검증 순서

1. 세 조각으로 분리
2. 서명 재계산 후 **상수 시간 비교**
3. payload 디코드
4. `exp` 만료 확인

```perl
return undef unless _eq($s64, _b64(hmac_sha256($input, $SECRET)));
```

### 서명을 먼저 검증하는 이유

서명 검증 전에 payload 를 신뢰하면 변조된 데이터를 그대로 쓰게 됩니다. 반드시 **서명이
맞은 뒤에** 내용을 사용합니다.

### 주의: 이건 학습용 최소 구현

알고리즘 혼동(`alg: none`/RS256 다운그레이드), 키 관리, 클레임 검증 등 실전 보안 요소는
전용 라이브러리를 쓰는 것이 안전합니다.

## Notes

- 테스트는 발급/정상검증/부재/변조/위조/만료를 검증합니다.
