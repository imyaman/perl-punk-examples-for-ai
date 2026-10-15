# Example 80 - multipart 파일 업로드 (Punk + Perl)

`multipart/form-data` 로 파일을 받아 **크기/확장자/빈 파일을 검증**하고, 경로 조작을
막아 안전하게 저장하는 예제입니다.

- `POST /files` → 업로드 (`201`, `Location` 반환)
- 허용 확장자: `.txt .csv .json .md`
- 최대 64KB, 빈 파일 거부
- `../../` 같은 파일명은 **basename 만** 취해 무력화
- `GET /files/:id` → 원본 바이트 + 원래 Content-Type + `ETag`(sha256)
- `GET /files/:id/meta`, `GET /files` → 메타/목록

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| POST   | /files          | 파일 업로드 |
| GET    | /files          | 목록 |
| GET    | /files/:id      | 내용 |
| GET    | /files/:id/meta | 메타데이터 |

## 동작 방식 (왜 이렇게 될까)

### 업로드 파트 읽기

Punk 는 파일 파트를 `Punk::Upload` 객체로 노출합니다.

```perl
my $up = $c->req->upload('file');   # filename/type/size/content/save
$up->save($path);
```

같은 이름이 여러 번 오면 `uploads` 는 배열ref 를, `upload` 는 첫 번째를 돌려줍니다.
일반 필드(`note`) 는 `$c->param('note')` 로 읽습니다.

### 검증을 먼저, 저장은 나중에

신뢰할 수 없는 입력이므로 **검증 통과 후에** 저장합니다.

| 조건 | 응답 |
|------|------|
| file 파트 없음 | `400` |
| 빈 파일(0 byte) | `400` |
| 허용하지 않는 확장자 | `415` |
| 크기 초과 | `413` |

### 경로 조작(Path Traversal) 방어

`filename` 은 클라이언트가 보내는 값이라 `../../etc/passwd` 일 수 있습니다. **디렉터리
부분을 제거하고 안전한 문자만 남깁니다.**

```perl
$safe =~ s{^.*[/\\]}{};        # 경로 제거
$safe =~ s/[^A-Za-z0-9._-]/_/g;
```

저장 파일명도 `f-0001-<safe>` 처럼 id 를 앞에 붙여 충돌과 덮어쓰기를 막습니다.

### 응답 Content-Type 을 직접 지정

`$c->text` 는 `text/plain; charset=utf-8` 를 스스로 붙입니다. 원본 MIME 타입을 그대로
보내려면 `$c->res` 의 `type`/`body` 를 씁니다.

```perl
my $res = $c->res;
$res->type($f->{type});
$res->header('ETag' => "\"$f->{sha256}\"");
$res->body($data);
return $res;
```

### 무결성

내용의 SHA-256 을 `ETag` 로 돌려줘, 받는 쪽이 변조 없이 같은 파일인지 확인할 수 있습니다.

## Notes

- 업로드 파일은 `$ENV{DAEHA_UPLOAD_DIR}` (기본 `/tmp/daeha-uploads`) 에 저장합니다.
- Punk 는 업로드 바이트를 **메모리**에 담으므로, 큰 파일은 별도 스트리밍 구성이 필요합니다.
- 파일명을 그대로 경로로 쓰지 않는 것이 핵심입니다.
- 테스트는 생성/조회/목록/경로조작/확장자/빈 파일/크기/누락/404 를 검증합니다.
