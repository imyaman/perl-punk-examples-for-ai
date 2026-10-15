# Example 51 - 입력 검증 (Punk + Perl)

재사용 가능한 검증 헬퍼로 요청 본문을 검사하고, 실패 시 **422 + 필드별 오류 목록**을
돌려주는 예제입니다.

- 필수값, 최소/최대 길이, 정수 여부, 범위, 정규식 패턴 지원
- 모든 오류를 모아서 `errors[]` 로 반환
- 성공 시 `201 Created`

## Routes

| Method | Path       | Description |
|--------|------------|-------------|
| GET    | /api/ping  | ping/pong |
| GET    | /api/healthz | k8s liveness |
| GET    | /api/readyz  | k8s readiness |
| POST   | /users     | name(2~20), email(형식), age(0~200, 선택) |

## 동작 방식 (왜 이렇게 될까)

### 규칙을 데이터로 표현

검증 규칙을 해시로 선언하면 로직과 분리됩니다. 새 필드를 추가하려면 규칙만 더하면
됩니다.

```perl
my @errors = _validate($body, {
    name  => { required => 1, min => 2, max => 20 },
    email => { required => 1, pattern => qr/^[^@\s]+@[^@\s]+\.[^@\s]+$/ },
    age   => { type => 'int', range => [0, 200] },
});
```

### 첫 오류에서 멈추지 않는다

모든 필드를 검사해 **오류를 한 번에 모아** 반환합니다. 클라이언트가 여러 문제를 한 번에
고칠 수 있어 UX 가 좋아집니다.

### 422 vs 400

문법은 맞지만 의미상 유효하지 않은 입력(검증 실패)은 `422 Unprocessable Entity` 가
적절합니다. JSON 파싱 자체가 안 되는 경우는 `400 Bad Request` 입니다.

### 오류 형식

`{ field, issue }` 배열로 반환합니다. 예제 38 의 RFC 7807 과 결합한 형태로,
`type/title/status/detail` 에 `errors` 를 더했습니다.

## Notes

- 테스트는 정상(옵션 포함), 필수 누락, 형식 오류, 복수 오류, 정수 오류를 검증합니다.
