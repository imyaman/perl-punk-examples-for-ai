# Example 24 - `markdown` 문서 사이트 (Punk + Perl)

마크다운 파일 디렉터리를 **문서 사이트**로 렌더링하는 예제입니다. 부팅 시 전체를
HTML 로 렌더해 얼려두므로, 요청은 해시 조회 수준으로 빠릅니다.

- `markdown '/docs' => 'docs', title => 'Daeha Guide';`
- 페이지 주소 = 디렉터리 기준 경로에서 `.md` 를 뗀 것
- index 파일(`index.md`)은 디렉터리 경로로 접힘

## URL 규칙

| 파일                    | 주소                       |
|-------------------------|----------------------------|
| `docs/index.md`         | `/docs`                    |
| `docs/getting-started.md` | `/docs/getting-started`  |

## Routes

| Method | Path                    | Description |
|--------|-------------------------|-------------|
| GET    | /api/ping               | ping/pong |
| GET    | /api/healthz            | k8s liveness |
| GET    | /api/readyz             | k8s readiness |
| GET    | /docs                   | 렌더된 index 문서 |
| GET    | /docs/getting-started   | 렌더된 문서 페이지 |

## 구성

```
docs/index.md
docs/getting-started.md
```

## 동작 방식 (왜 이렇게 될까)

### 부팅 시 렌더 후 동결

`markdown` 은 부팅 때 디렉터리를 훑어 모든 `.md` 를 HTML 로 렌더하고 **조회
테이블에 얼립니다**. 요청이 올 때마다 파싱하지 않으므로 빠릅니다. 대신 문서를
바꾸면 서버를 다시 시작해야 반영됩니다.

### URL 규칙

`.md` 를 뗀 경로가 주소가 되고, `index.md` 는 디렉터리 경로로 접힙니다. 뒤에
`/` 나 `.md` 가 붙은 요청은 정식 주소로 리다이렉트됩니다.

### 정적 사이트와의 차이

`static`(예제 23)은 파일을 **그대로** 내보내고, `markdown` 은 **렌더링**해서
내보냅니다. 마크다운 렌더러와 내비게이션·목차·검색(옵션)이 붙는다는 점이
다릅니다.

### 옵션

`title`, `index`(디렉터리를 뜻하는 파일명), `search`(부팅 시 검색 인덱스 빌드),
`edit_url` 등으로 동작을 조정합니다.

## Notes

- 문서 내용이 바뀌면 서버 재시작이 필요합니다(부팅 시 동결).
