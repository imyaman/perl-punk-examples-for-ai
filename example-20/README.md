# Example 20 - HTTP Basic 인증 (Punk + Perl)

`Authorization: Basic base64(user:pass)` 를 검사하는 예제입니다. 실패 시
`WWW-Authenticate: Basic` 챌린지 헤더를 함께 보내 브라우저 기본 인증창을 띄웁니다.

- `$c->req->header('authorization')` → `^Basic\s+(\S+)$` 파싱
- `MIME::Base64::decode_base64` 로 디코드 → `user:pass` 분해
- 실패 시 `$c->header('WWW-Authenticate' => 'Basic realm="Daeha"')` 후 401

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong (공개) |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /api/basic/me   | Basic 자격증명 필요 |

사용자: `alice/pass123`, `bob/hunter2`

## 동작 방식 (왜 이렇게 될까)

### Basic 은 base64 이지 암호화가 아니다

`Authorization: Basic <base64(user:pass)>` 의 base64 는 **인코딩일 뿐**입니다. 평문과
다르지 않으므로 **반드시 HTTPS 위에서** 써야 합니다. 이 예제는 로컬 HTTP 로 동작만
보여줍니다.

### 파싱과 검증의 분리

1. 스킴 확인 (`Basic `)
2. base64 디코드 (`eval` 로 감싸 깨진 입력 방어)
3. `user:pass` 분리 — **비밀번호에 콜론이 있을 수 있어** `split /:/, $dec, 2` 로 2조각만
4. 저장소 조회 후 일치 확인

각 단계 실패마다 다른 메시지를 주되, 응답은 모두 401 입니다.

### 챌린지 헤더

자격증명이 없을 때 `WWW-Authenticate: Basic realm="Daeha"` 를 보내면 브라우저가
사용자/비밀번호 입력창을 띄웁니다. 401 과 이 헤더가 한 세트입니다.

### 가드 재사용

`under '/api/basic' => $basic` 로 구역 전체를 보호합니다. Bearer(예제 19)와 동일한
가드 구조이므로, 스킴만 바꿔 같은 패턴을 재사용할 수 있습니다.

## Notes

- 저장소는 데모용 인메모리 해시이며, 비밀번호를 평문 비교합니다(실제로는 해시 비교).
- `realm` 은 자격증명이 적용되는 보호 영역 이름입니다.
