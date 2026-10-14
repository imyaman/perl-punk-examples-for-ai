# Example 5 - 파일 업로드 (multipart/form-data) (Punk + Perl)

multipart 파일 업로드를 처리하는 예제입니다.

- `$c->upload('field')` 로 업로드 객체(Punk::Upload) 획득
- `filename()`, `size()`, `type()`, `content()` 등 사용
- 여러 파일 업로드는 `$c->req->uploads()` 에서 해시로 접근

## Routes

| Method | Path                        | Description |
|--------|-----------------------------|-------------|
| GET    | /api/ping                   | ping/pong |
| GET    | /api/healthz                | k8s liveness |
| GET    | /api/readyz                 | k8s readiness |
| POST   | /api/upload                 | 단일 파일 업로드 (필드명: `file`) |
| POST   | /api/upload-multiple        | 여러 파일 업로드 (필드명: `files[]`) |
| GET    | /api/uploads                | 업로드 기록 조회 |

## 단일 업로드 예제

```bash
curl -s -X POST http://localhost:3015/api/upload \
  -F "file=@hello.txt" \
  -F "title=My Document"
```

응답:
```json
{
  "uploaded": {
    "id": "upl_...",
    "filename": "hello.txt",
    "size": 123,
    "type": "text/plain",
    "title": "My Document",
    "uploaded_at": "2026-09-15T14:00:00Z"
  }
}
```

## 여러 파일 업로드

```bash
curl -s -X POST http://localhost:3015/api/upload-multiple \
  -F "files[]=@a.txt" \
  -F "files[]=@b.txt"
```

## Punk::Upload 주요 메서드

- `filename()` — 클라이언트가 보낸 원래 파일명
- `size()` — 파일 크기(바이트)
- `type()` — MIME 타입 (Punk이 제공)
- `content()` — 파일 내용(문자열/바이트)
- `name()` — 폼 필드명 (예: "file", "files[]")

> 주의: 이 예제의 `$upload->content()` 는 Punk::Upload 이 제공하는 메서드이며,
> 모든 Punk 버전에서 동일하게 제공되지 않을 수 있습니다. 실제 환경에서는
> `$c->req->upload(...)` 의 문서/동작을 확인하세요.

## 에러 응답

- 400 — 파일 필드 없음 / files[] 필드 없음
- 500 — 파일 읽기 오류 (드물게)

## 동작 방식 (왜 이렇게 될까)

### multipart 파싱은 프레임워크가 한다

`Content-Type: multipart/form-data` 요청은 Punk가 파싱해서 핸들러에 넘겨줍니다.
그래서 핸들러는 원시 바디를 직접 자르지 않고, 파싱된 결과에 접근합니다.

- 파일 하나 → `$c->upload('file')` 가 `Punk::Upload` 객체를 반환
- 파일 여러 개 → `$c->req->uploads()` 가 **필드명 → 업로드(들)** 해시ref를 반환
- 일반 폼 필드(`title` 등) → `$c->req->form()` 에서 읽음

### `files[]` 가 배열이 되는 이유

HTML 폼 관례상 같은 이름 `files[]` 를 여러 번 보내면, `$c->req->uploads()` 의 그 키가
**업로드 배열**이 됩니다. 그래서 `ref $files_field eq 'ARRAY'` 를 확인하고
`($files_field)` 로 감싸 단일/다중을 같은 코드로 처리합니다.

### 업로드는 "요청 스코프" 객체

`Punk::Upload` 는 이번 요청의 파싱 결과를 감싼 객체입니다. `filename/size/type/content`
는 그 요청에 담긴 값이고, 파싱이 끝난 뒤에는 핸들러가 원하는 대로(여기서는 인메모리
레코드로) 복사해 둡니다. 대용량 업로드를 스트리밍으로 다루고 싶다면 Punk가 제공하는
바디 청크 읽기(`body_each`/`body_to`)를 쓰는 것이 설계 의도에 맞습니다.

### 파일명은 그대로 믿지 않는다

`_safe_filename` 이 `[^a-zA-Z0-9._-]` 를 `_` 로 치환합니다. 저장/표시에 쓰일 이름을
정제하는 것은 애플리케이션 몫입니다(원본은 `original` 필드에 보존).

## Notes

- 업로드 기록은 프로세스 인메모리에 저장되며, 재시작 시 초기화됩니다.
- 워커는 1개로 실행됩니다(--workers 1).
