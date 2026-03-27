# Fork sync guide — dieison-depra/no-js ↔ ErickXavier/no-js

## Remotes

| Remote | URL | Role |
|--------|-----|------|
| `origin` | `github.com:dieison-depra/no-js` | Fork — this repo |
| `upstream` | `github.com:ErickXavier/no-js` | Upstream — original framework |

The fork is a **superset** of the upstream. Every commit in `upstream/main` is
reachable from `origin/main` through merge commits. The fork adds features,
fixes, and test coverage on top of whatever the upstream ships.

---

## What the fork adds (never discard in a merge)

### Source code additions

| File | Addition | Reason |
|------|----------|--------|
| `src/animations.js` | DOM guard in `_injectBuiltInStyles()`: `if (document.querySelector('[data-nojs-animations]')) { _stylesInjected = true; return; }` | B2: prevents double-injection of keyframes when the prebuild plugin already placed the `<style>` tag in static HTML |
| `src/directives/conditionals.js` | `el.removeAttribute('data-nojs-pending')` at the start of every `update()`/`render()` in `if`, `else-if`, `else`, `show`, `hide` | B5: lifts the `visibility:hidden` applied by the `inject-visibility-css` prebuild plugin once the directive takes control |

### Test files unique to fork

| File | Content |
|------|---------|
| `__tests__/audit-changes.test.js` | Regression guards for all externally proposed changes (M1–M8 series) |
| `__tests__/leak-regression.test.js` | Memory/listener leak regression suite (T1–T6) |
| `__tests__/inject-head-attrs.test.js` | Tests for the `inject-head-attrs` build script |

### Documentation sections unique to fork

| File | Fork-only sections |
|------|-------------------|
| `docs/md/routing.md` | Deployment section (nginx, Apache, Netlify, Vercel, Cloudflare, Firebase, hash mode), Per-Route Document Title, Route Head Attributes |
| `docs/md/data-fetching.md` | Skeleton Placeholders section, Interceptors section |
| `docs/md/build-tools.md` | Rewritten to reference `nojs-cli-bun` instead of standalone scripts |
| `docs/md/resource-hints.md` | Rewritten to reference `nojs prebuild` instead of `node scripts/inject-resource-hints.js` |

### Files removed from fork (moved to nojs-cli-bun)

The `scripts/` directory was deleted from this repo. Its contents were ported
as plugins to `ErickXavier/nojs-cli-bun`:

| Removed script | CLI plugin |
|----------------|------------|
| `scripts/inject-head-attrs.js` | `inject-head-attrs` |
| `scripts/inject-resource-hints.js` | `inject-resource-hints` |

---

## Merge procedure

```bash
# 1. Fetch latest upstream
git fetch upstream

# 2. Check what's new
git log --oneline upstream/main ^main

# 3. Merge
git merge upstream/main --no-edit

# 4. Resolve conflicts (see rules below)

# 5. Rebuild bundles
npm run build

# 6. Run tests — all 19 suites must pass
npm test

# 7. Commit and push
git commit -F - <<'EOF'
merge: bring upstream/main into local main
[brief description of what upstream added]
EOF
git push origin main
```

---

## Conflict resolution rules

### Per-file rules

| File / pattern | Rule | Reason |
|----------------|------|--------|
| `src/animations.js` | **`--ours`** | Fork has B2 DOM guard; upstream doesn't |
| `src/directives/conditionals.js` | **`--ours`** | Fork has B5 `removeAttribute`; upstream doesn't |
| `docs/md/routing.md` | **`--ours`** | Fork has Deployment + page-title + head-attrs sections; upstream has subset |
| `docs/md/data-fetching.md` | **`--ours`** | Fork has skeleton + interceptors sections |
| `docs/md/build-tools.md` | **`--ours`** | Fork version references CLI |
| `docs/md/resource-hints.md` | **`--ours`** | Fork version references CLI |
| `__tests__/router.test.js` | **`--ours`** | Fork has full test coverage incl. M1–M8, skip patches; upstream subset |
| `__tests__/directives-data.test.js` | **`--ours`** | Fork has M3 skeleton tests + M6 header warning tests |
| `dist/*` | **rebuild** — never pick a side | Bundles must be recompiled from the resolved source |
| All other `src/` files | **`--theirs`** (upstream improvements) | Fork has no additions to these; take upstream fixes/features |

### When upstream changes a file the fork also changed

Check the diff of the conflicted file first:

```bash
# See what upstream changed vs the merge base
git diff :1:<file> :3:<file>

# See what fork changed vs the merge base
git diff :1:<file> :2:<file>
```

If upstream's change is to a section the fork doesn't touch → manual merge keeping both.
If upstream's change overlaps a fork addition → keep the fork addition, take upstream change around it.

---

## Fork invariants — must hold after every merge

Run this checklist before pushing:

```bash
# 1. B2 guard present
grep -n 'data-nojs-animations' src/animations.js
# Expected: one line inside _injectBuiltInStyles() before _stylesInjected = true

# 2. B5 removeAttribute present in all 5 directives
grep -n 'removeAttribute.*data-nojs-pending' src/directives/conditionals.js
# Expected: 5 matches (if, else-if, else, show, hide)

# 3. scripts/ directory absent
ls scripts/ 2>/dev/null && echo "ERROR: scripts/ should not exist" || echo "OK"

# 4. All tests pass
npm test
# Expected: 19 suites, 0 failures (3 skipped — jsdom navigation limitation)
```

---

## Feature mapping: fork features pending upstream submission

These fork features exist locally and may eventually be submitted as upstream PRs.
Until merged upstream, they must be preserved on every sync.

| Feature | Fork file(s) | PR status |
|---------|-------------|-----------|
| B2 — prebuild animation CSS guard | `src/animations.js` | Not submitted |
| B5 — prebuild visibility CSS cleanup | `src/directives/conditionals.js` | Not submitted |
| Deployment docs | `docs/md/routing.md` | Not submitted |
| Route head-attrs docs expansion | `docs/md/routing.md` | Not submitted |
| Audit + leak regression tests | `__tests__/audit-changes.test.js`, `__tests__/leak-regression.test.js` | Not submitted |

---

## nojs-cli-bun relationship

Post-build optimizations live in a separate package:

| Repo | npm | Role |
|------|-----|------|
| `ErickXavier/NoJS-CLI` (fork: `dieison-depra/nojs-cli-bun`) | `@erickxavier/nojs-cli` | CLI + all prebuild plugins |

The framework source (`no-js`) deliberately contains **no** post-build scripts.
Anything that was previously in `scripts/` is a plugin in `nojs-cli-bun`.
The two repos sync independently — framework changes here do not require a
`nojs-cli-bun` release, and vice versa.

The only coupling points are:
- `data-nojs-animations` attribute (B2): framework reads it; CLI plugin writes it
- `data-nojs-pending` attribute (B5): framework removes it; CLI plugin writes it
- Route template attributes (`page-title`, `page-description`, `page-canonical`,
  `page-jsonld`): framework evaluates at runtime; CLI plugin pre-injects at build time

If either attribute name changes in the framework, the corresponding plugin in
`nojs-cli-bun` must be updated in the same release.

---

## Last sync

| Event | Date | Upstream tip | Fork tip |
|-------|------|-------------|----------|
| Merge upstream/main | 2026-03-26 | `6088017` | `4c9c375` |
