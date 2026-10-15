# Example 25 - `views` + `render` 템플릿 (Punk + Perl)

HTML 템플릿 엔진(Stencil)을 등록하고 핸들러에서 렌더하는 예제입니다.

- `views Stencil => { template_dir => 'templates' }`
- `$c->render('page', { ... })` → `templates/page.tmpl` 렌더
- 템플릿 문법: `{% 변수 %}`, `{% if ... %}{% end %}`, `{% for x in list %}{% end %}`

## Routes

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | /api/ping       | ping/pong |
| GET    | /api/healthz    | k8s liveness |
| GET    | /api/readyz     | k8s readiness |
| GET    | /page           | 템플릿 렌더 (HTML) |

## 구성

```
templates/page.tmpl
```

## 동작 방식 (왜 이렇게 될까)

### 뷰 엔진은 이름으로 등록

`views Stencil => {...}` 는 뷰 엔진을 등록하고, **처음 등록한 것이 기본**이 됩니다.
`$c->render('page')` 는 `template_dir` 기준 `page.tmpl` 을 찾아 렌더합니다.

### 하나의 구분자 쌍

Stencil 은 `{% %}` **한 쌍만** 씁니다.

- `{% name %}` — 변수 출력(HTML 이스케이프됨)
- `{% raw name %}` — 이스케이프 없이 출력
- `{% name | upper %}` — 필터 체이닝
- 블록은 항상 `{% end %}` 로 닫습니다 (`endfor`/`endif` 가 아님)

```
{% if items %}
  {% for item in items %}
    <li>{% item %} (#{% loop.index1 %})</li>
  {% end %}
{% else %}
  <p>No items.</p>
{% end %}
```

### 반복에 `loop` 가 딸려온다

`for` 안에서는 암묵 변수 `loop` 가 스코프에 있습니다(`index`, `index1`, `last`,
`size` 등). 중첩 루프에서 바깥을 참조하려면 `{% set outer = loop %}` 로 잡아둡니다.

### 부팅 시 컴파일

템플릿 문법 오류는 **첫 렌더가 아니라 부팅(또는 첫 컴파일)에서** 잡힙니다. 그래서
문법 오타가 요청마다 500으로 새지 않고 빨리 드러납니다.

### JSON vs HTML

`$c->json` 은 API 용, `$c->render` 는 HTML 페이지용입니다. 한 앱에서 `/api/*` 는
JSON, `/page` 는 템플릿으로 나눠 쓸 수 있습니다.

## Notes

- `render` 는 UTF-8 바이트를 반환하며 `Content-Type: text/html` 로 나갑니다.
