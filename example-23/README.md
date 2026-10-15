# Example 23 - `static` 정적 파일 서빙 (Punk + Perl)

디렉터리의 파일을 URL 접두사 아래로 서빙하는 예제입니다.

- `static '/static' => 'public';` — `/static/*` 를 `./public/*` 에 매핑
- 확장자에 따라 `Content-Type` 자동 설정
- 없는 파일은 404

## Routes

| Method | Path                | Description |
|--------|---------------------|-------------|
| GET    | /api/ping           | ping/pong |
| GET    | /api/healthz        | k8s liveness |
| GET    | /api/readyz         | k8s readiness |
| GET    | /static/hello.txt   | 텍스트 파일 |
| GET    | /static/data.json   | JSON 파일 |
| GET    | /static/index.html  | HTML 파일 |

## 구성

```
public/hello.txt
public/data.json
public/index.html
```

## 동작 방식 (왜 이렇게 될까)

### 경로 매핑

`static '/static' => 'public'` 는 URL 접두사 `/static` 을 파일시스템 디렉터리
`public` 에 붙입니다. 요청 `/static/hello.txt` 는 `public/hello.txt` 를 찾습니다.
디렉터리는 앱 실행 디렉터리 기준 상대 경로입니다.

### Content-Type 자동

Punk::Static 이 확장자로 MIME 타입을 정합니다(`.txt` → `text/plain`,
`.json` → `application/json`, `.html` → `text/html`). 그래서 `data.json` 은
그대로 JSON 으로 해석됩니다.

### 정적 파일도 라우팅의 일부

`static` 은 PSGI 수준에서 처리되지만, 앱의 라우팅과 공존합니다. 접두사가
겹치지 않으면 `/api/*` 는 Punk 라우트가, `/static/*` 는 파일 핸들러가 담당합니다.
없는 파일은 404 로 떨어집니다.

### 언제 쓰나

CSS/JS/이미지, 빌드 산출물, 문서 파일 등 "코드가 아닌" 자산을 API 옆에 둘 때
씁니다. 별도 웹서버 없이도 개발/소규모 배포가 가능합니다.

## Notes

- 업로드된 파일을 다시 서빙하는 용도(예제 5)와 짝을 이룹니다.
