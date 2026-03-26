# Build Tools

No.JS integrates with `@erickxavier/nojs-cli` to pre-populate `<head>` in
your generated HTML files. The CLI prebuild pipeline runs after your bundler
produces the output directory.

> **Why bother?** No.JS directives run in the browser — on the very first
> request, a crawler or browser receives HTML whose `<head>` may be empty.
> Build-time injection fills those tags *before any JavaScript runs*, which
> matters for:
>
> - **SEO**: Googlebot and other crawlers index the initial HTML response.
> - **Social sharing**: Open Graph / Twitter Card parsers do not execute JS.
> - **LCP / TTFB**: `<link rel="preload">` hints only help if they arrive in
>   the initial HTML — hints injected by JS fire too late for the first load.

Use the CLI prebuild command as part of your build pipeline:

```json
"scripts": {
  "build": "node build.js && nojs prebuild"
}
```

---

## `inject-head-attrs` plugin

**What it does:** Scans every `.html` file in the output directory and injects
or updates `<title>`, `<meta name="description">`, `<link rel="canonical">`,
and `<script type="application/ld+json" data-nojs>` for No.JS head-management
directives that contain **static values**.

**Related PRs / features:**
- [Head Management directives](head-management.md) — `page-title`,
  `page-description`, `page-canonical`, `page-jsonld` as body directives
  (PR #27).
- [Route head attributes](routing.md#route-head-attributes) — the same four
  attributes declared directly on `<template route>` elements (PR #34).

### Usage

Enable in `nojs-prebuild.config.js`:

```js
export default {
  plugins: {
    'inject-head-attrs': true,
  },
}
```

### What is injectable at build time

Only **static string literals** can be resolved without executing JavaScript:

| Expression | Injectable? | Reason |
|---|---|---|
| `page-title="'About Us \| Store'"` | ✅ Yes | Bare string literal |
| `page-canonical="'/about'"` | ✅ Yes | Bare string literal |
| `page-jsonld` body content | ✅ Always | JSON is verbatim, no evaluation |
| `page-title="product.name + ' \| Store'"` | ❌ No | Depends on runtime state |
| `page-description="product.description"` | ❌ No | Variable reference |
| `page-canonical="'/products/' + product.slug"` | ❌ No | Expression |

Dynamic directives are left in the DOM untouched — the runtime will evaluate
them as usual when the page loads.

### Body directives example

```html
<!-- Static: injected at build time AND updated at runtime (reactive) -->
<div hidden page-title="'About Us | My Store'"></div>
<div hidden page-description="'We sell the best products online'"></div>
<div hidden page-canonical="'/about'"></div>
<div hidden page-jsonld>{"@context":"https://schema.org","@type":"WebPage","name":"About Us"}</div>

<!-- Dynamic: only updated at runtime -->
<div hidden page-title="product.name + ' | My Store'"></div>
```

After the build runs:

```html
<head>
  <title>About Us | My Store</title>
  <meta name="description" content="We sell the best products online">
  <link rel="canonical" href="/about">
  <script type="application/ld+json" data-nojs>{"@context":"https://schema.org","@type":"WebPage","name":"About Us"}</script>
</head>
```

### Route template example (SPA)

For a standard SPA with a single `index.html`, the plugin uses the root route
(`route="/"`) as the default page metadata:

```html
<template route="/"
  page-title="'My Store — Home'"
  page-description="'Shop our full catalogue'"
  page-canonical="'https://mystore.com/'"
  page-jsonld='{"@context":"https://schema.org","@type":"WebSite","name":"My Store"}'>
  <h1>Home</h1>
</template>
```

Resulting `<head>` after the build runs:

```html
<head>
  <title>My Store — Home</title>
  <meta name="description" content="Shop our full catalogue">
  <link rel="canonical" href="https://mystore.com/">
  <script type="application/ld+json" data-nojs>{"@context":"https://schema.org","@type":"WebSite","name":"My Store"}</script>
</head>
```

### Route template example (SSG)

When using a static site generator that produces one HTML file per route (see
[SSG guide](ssg.md)), each file contains only the relevant `<template route>`
element. The plugin processes each file independently:

```
dist/
  index.html          ← contains <template route="/" page-title="'Home | Store'">
  about/index.html    ← contains <template route="/about" page-title="'About | Store'">
  products/index.html ← contains <template route="/products" page-title="'Products | Store'">
```

Each file gets its own correct `<title>` and metadata injected.

### Precedence

If both a body directive and a route template attribute are present for the
same element, the **body directive takes precedence**:

```html
<!-- Body directive wins -->
<div hidden page-title="'Explicit Title'"></div>
<template route="/" page-title="'Route Title'">...</template>
<!-- → <title>Explicit Title</title> -->
```

---

## `inject-resource-hints` plugin

**What it does:** Scans every `.html` file in the output directory and injects
`<link rel="preload">`, `<link rel="preconnect">`, and
`<link rel="prefetch">` hints for No.JS `get=` directives and remote route
templates.

**Related PR / feature:** [Resource Hints](resource-hints.md) (PR #33).

### Usage

```js
export default {
  plugins: {
    'inject-resource-hints': true,
  },
}
```

See [Resource Hints →](resource-hints.md) for full documentation.

---

## Running the full pipeline

```json
{
  "scripts": {
    "build": "node build.js",
    "postbuild": "nojs prebuild"
  }
}
```

Using `postbuild` ensures the pipeline runs automatically after every `npm run build`.

---

**Next:** [Head Management →](head-management.md) | [Resource Hints →](resource-hints.md)
