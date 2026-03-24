# Analysis: Keyed Reconciliation Performance — S2 and S5 Corner Cases

## Context

PR #19 (`feat/p3-loop-key-reconciliation`) introduced key-based reconciliation for `each`
and `foreach` directives. Initial JSDOM benchmarks showed that keyed reconciliation loses to
full-rebuild in two specific scenarios:

- **S2 — sort/reverse**: entire list reordered (tested via `[...items].reverse()`)
- **S5 — full replacement**: all items replaced with new IDs (zero key overlap)

This document has been updated with findings from a real-browser Playwright/CDP benchmark
(`__benchmarks__/keyed-vs-rebuild.bench.spec.ts`, added in `bench/playwright-keyed-vs-rebuild`),
which substantially changes the picture for S2 and clarifies the root cause of S5.

---

## Real-Browser Benchmark Results (Chromium, CDP)

Benchmark: `npm run bench:playwright` — 5 scenarios × 3 list sizes, 7 runs each (first 2
discarded as JIT warmup), median wall-clock time (`performance.now()` inside browser).

### Scenario results (median ms, lower = better)

#### n = 50

| Scenario | keyed | rebuild | ratio |
|---|---|---|---|
| S1 push (append 1) | 0.08 | 0.33 | **0.24× ✓ keyed faster** |
| S2 reverse (full sort) | 0.16 | 0.34 | **0.47× ✓ keyed faster** |
| S3 splice (remove middle) | 0.09 | 0.31 | **0.29× ✓ keyed faster** |
| S4 update (same keys, new data) | 0.07 | 0.32 | **0.22× ✓ keyed faster** |
| S5 replace (zero key overlap) | 0.41 | 0.35 | **1.17× △ rebuild faster** |

#### n = 200

| Scenario | keyed | rebuild | ratio |
|---|---|---|---|
| S1 push (append 1) | 0.09 | 0.38 | **0.24× ✓ keyed faster** |
| S2 reverse (full sort) | 0.31 | 0.72 | **0.43× ✓ keyed faster** |
| S3 splice (remove middle) | 0.18 | 0.67 | **0.27× ✓ keyed faster** |
| S4 update (same keys, new data) | 0.14 | 0.69 | **0.20× ✓ keyed faster** |
| S5 replace (zero key overlap) | 1.21 | 0.93 | **1.30× △ rebuild faster** |

#### n = 500

| Scenario | keyed | rebuild | ratio |
|---|---|---|---|
| S1 push (append 1) | 0.10 | 0.41 | **0.24× ✓ keyed faster** |
| S2 reverse (full sort) | 0.57 | 2.01 | **0.28× ✓ keyed faster** |
| S3 splice (remove middle) | 0.29 | 1.14 | **0.25× ✓ keyed faster** |
| S4 update (same keys, new data) | 0.22 | 1.93 | **0.11× ✓ keyed faster** |
| S5 replace (zero key overlap) | 2.71 | 1.71 | **1.58× △ rebuild faster** |

### Zero-overlap bailout impact (S5 only, PR #25 — now closed)

| n | with bailout | without bailout | full-rebuild | bailout gain | keyed+bailout vs rebuild |
|---|---|---|---|---|---|
| 50 | 0.41 | 0.39 | 0.35 | 0.95× (marginal) | **1.17× △ rebuild faster** |
| 200 | 1.21 | 1.56 | 0.93 | **1.29× faster** | **1.30× △ rebuild faster** |
| 500 | 2.71 | 2.74 | 1.71 | 1.01× (neutral) | **1.58× △ rebuild faster** |

---

## S2 Hypothesis — Validated

The JSDOM analysis noted that `processTree()` cost likely dominates in real browsers,
potentially making S2 a keyed win in production despite the JSDOM result.

**The Chromium benchmark confirms this.** Keyed wins S2 at all list sizes (0.28–0.47×).

The reason: for existing items, `reconcileItems()` calls `Object.assign(wrapper.__ctx.__raw, childData)` +
`wrapper.__ctx.$notify()`. Full-rebuild calls `_disposeChildren(el) + el.innerHTML="" +
processTree(wrapper)` for every item. In a real browser, `processTree` involves actual DOM
property access, CSS computation, and JS object allocation — the dominant cost at any list size.

**Consequence**: Opt 3 (LIS minimal moves) and Opt 4 (LIS + threshold bailout) are no longer
motivated by real-world data. They would add complexity without addressing any actual
performance problem. These optimizations are **deprioritized indefinitely**.

---

## S5 Root Cause — Clarified

### What the JSDOM analysis got right

Individual `wrapper.remove()` calls are more expensive than `innerHTML=""` per remove. This
is the mechanism identified in the original analysis.

### What the real-browser data adds

Even with the zero-overlap bailout (PR #25), keyed loses to full-rebuild in S5 at all sizes.
The bailout helps at n=200 (+29%) but is neutral at n=50 and n=500.

The root cause is broader than just the removal phase:

1. **Key evaluation overhead**: `reconcileItems()` must call `evaluate(keyExpr, tempCtx)` for
   every item in the new list to build `nextKeySet`, even before the removal phase begins.
   Full-rebuild skips this entirely.

2. **Full path overhead (scan + clear + create)**: Even with bulk clear, the keyed path does:
   - O(n) key evaluation to build `newOrder` + `nextKeySet`
   - Bulk clear via `_disposeChildren + innerHTML=""` (Opt 1)
   - O(n) wrapper creation + `processTree()` for every new item

   Full-rebuild does:
   - `_disposeChildren + innerHTML=""` (same single clear)
   - O(n) wrapper creation + `processTree()` for every new item
   - **No key evaluation pass**

3. **The advantage of keyed (reusing `processTree` calls) evaporates when there is zero
   key overlap** — keyed must call `processTree()` for all n new items anyway, identical
   to full-rebuild. It gains nothing from the keyed path and pays the evaluation overhead.

### S5 as a semantic anti-pattern

When a developer uses `key="item.id"` and then replaces every item with a new ID, the `key`
attribute provides no benefit — it is semantically equivalent to not using `key` at all.
This is a documentation issue as much as an algorithmic one.

A usage note should accompany the `key` attribute documentation:

> Use `key` when items are expected to **persist across updates** (add/remove individual
> items, reorder, edit in place). If you regularly replace the entire list with new IDs
> (e.g., switching datasets), `key` adds overhead with no benefit — omit it.

---

## Problem Description (updated)

### S2 — Sort/Reverse (no longer a practical problem)

The reorder phase uses a greedy forward pass (n `insertBefore` calls for a full reversal).
This loses in JSDOM but wins in real Chromium because `processTree()` cost dominates.
**S2 is not a problem in production environments.**

### S5 — Full Replacement (still a problem, root cause is the key evaluation overhead)

The keyed path is more expensive than full-rebuild for zero-overlap updates because it pays
O(n) key evaluation without gaining anything from node reuse. The bailout (Opt 1) reduces
the removal overhead but does not eliminate the evaluation overhead.

---

## Literature and Framework Research

### Vue 3 — `patchKeyedChildren` + `getSequence`

Vue 3 uses a **five-phase algorithm**:
1. Sync common prefix (advance while keys match from start)
2. Sync common suffix (advance while keys match from end)
3. Pure mounts (old exhausted)
4. Pure unmounts (new exhausted)
5. Unknown sequence → LIS-based minimal moves

**LIS (Longest Increasing Subsequence) optimization:**

After the prefix/suffix passes, Vue 3 builds `newIndexToOldIndexMap` (maps each new position
to its old index). It then computes the LIS of this array in O(n log n) using patience sort.
Nodes at LIS indices stay in place; all others get `insertBefore`.

```
min_moves = toBePatched - LIS_length
```

**Does LIS solve S2?**
For a full reversal, `newIndexToOldIndexMap = [n, n-1, ..., 2, 1]` — a strictly decreasing
sequence. LIS of a strictly decreasing sequence = 1. So `n - 1` nodes still get
`insertBefore` calls. LIS saves exactly 1 move. **Vue 3 does not solve S2.**
(Moot point — S2 is not a real-browser problem per the Chromium benchmark.)

**Does LIS solve S5?**
With zero key overlap, `newIndexToOldIndexMap` stays all zeros (new nodes). No LIS is
computed (`moved` flag stays false). n individual unmounts + n mounts still occur.
**Vue 3 does not solve S5.**

### Solid.js — `mapArray` + `reconcileArrays`

`mapArray` tracks reactive value identity (not explicit keys). The DOM reconciler
(`reconcileArrays`, derived from udomdiff) uses a sequential-match heuristic. No bailout
implemented for zero-overlap.

### Inferno — `patchKeyedChildrenComplex`

Two-tier strategy:
- **Small lists** (`bLength < 4 || (aLeft | bLeft) < 32`): nested O(n²) loop with
  `canRemoveWholeContent` flag — if no key matches early in the scan, bulk-removes all
  remaining old nodes at once. Limited form of zero-overlap bailout.
- **Large lists**: same LIS algorithm as Vue 3 but using typed `Int32Array` (more
  cache-friendly). Also uses `moved` flag to skip LIS when order is already preserved.

### DocumentFragment Batching

Modern V8/Blink already defers layout recalculation until the JS task completes or a
layout-querying property is read. Not recommended — no benefit, sometimes marginally slower.

---

## Proposed Optimizations (updated)

### Optimization 1 — Zero-overlap bailout (S5, partial fix) — PR #25, now closed

Implemented as `_zeroOverlapBailout()` in `src/directives/loops.js`. Detects when no old
key survives in the new list, then bulk-clears via `_disposeChildren(el) + el.innerHTML="" +
keyMap.clear()` instead of n individual `wrapper.remove()` calls.

**Real-browser benchmark result**: helps at n=200 (+29%), neutral at n=50 and n=500.
Keyed still loses to full-rebuild in S5 at all sizes, because key evaluation overhead
(not just removal overhead) is the dominant cost.

**Status**: PR #25 closed — insufficient evidence of utility. May be reopened if Opt 5
proves worth pursuing as a prerequisite.

### Optimization 2 — Common prefix/suffix sync

The most frequent real-world list updates are append/prepend/update at the edges. Syncing
prefix and suffix before entering the main reconciliation path turns these into O(1) DOM ops.

```js
// Track previous newOrder between renders.
// Sync prefix: advance `start` while keys match from the front.
// Sync suffix: retreat `end` while keys match from the back.
// Only reconcile the segment [start..end].
```

For appending 1 item to a list of n: prefix sync covers all n existing items in one pass,
suffix needs 0 checks → reconcile only 1 new item. O(1) DOM ops instead of O(n).

- **Effort**: medium (requires storing `prevOrder` between renders)
- **Gain**: high for the most common real-world patterns (S1 scenario)
- **S5 impact**: none — zero-overlap means no prefix or suffix matches

### Optimization 3 — LIS-based minimal moves ~~⚠️~~ — DEPRIORITIZED

Originally proposed for S2. Real-browser benchmarks show keyed already wins S2 at all sizes
(0.28–0.47×). LIS would add O(n log n) complexity per render with no real-world benefit.

**Status**: deprioritized indefinitely.

### Optimization 4 — LIS + threshold bailout — DEPRIORITIZED

Deprioritized together with Opt 3 (LIS is a prerequisite). S2 is not a problem in production.

**Status**: deprioritized indefinitely.

### Optimization 5 — Overlap-threshold bailout (NEW — fixes S5 for partial replacements)

Generalization of Opt 1. Instead of only bailing out when overlap = 0, bail out when the
surviving key fraction falls below a threshold (e.g., 20%):

```js
function _overlapThresholdBailout(keyMap, nextKeySet, el, threshold = 0.20) {
  if (keyMap.size === 0) return false;
  let survivors = 0;
  for (const key of keyMap.keys()) {
    if (nextKeySet.has(key)) survivors++;
  }
  const fraction = survivors / keyMap.size;
  if (fraction >= threshold) return false;
  // Very few keys survive — full rebuild is cheaper than processing individually.
  _disposeChildren(el);
  el.innerHTML = "";
  keyMap.clear();
  // Caller must rebuild the missing entries; survivors that were cleared will be
  // recreated in the create phase (keyMap is now empty).
  return true;
}
```

**Tradeoffs vs Opt 1:**
- Covers partial replacements (e.g., loading a new page of results with a few ID collisions)
- Discards surviving nodes even when some keys match — those nodes must be recreated
- Threshold choice: too high → discards nodes that could be reused; too low → doesn't help
- **Requires benchmark validation before implementation** — threshold sensitive to `processTree` cost vs
  key-evaluation cost at each list size

**Open question**: What threshold gives the best median across S5 variants at realistic sizes?
Needs a dedicated benchmark sweep (e.g., overlap = 0%, 10%, 20%, 30%, 50%) before any code is written.

**Status**: hypothesis only — do not implement without benchmark evidence.

---

## Updated Priority Matrix

| Optimization | Effort | S5 gain | S2 gain | Risk | Status |
|---|---|---|---|---|---|
| Zero-overlap bailout (Opt 1) | Low | Partial (n=200) | — | Very low | Closed (PR #25) |
| Prefix/suffix sync (Opt 2) | Medium | — | Medium (partial sort) | Low | Candidate |
| LIS minimal moves (Opt 3) | High | — | None (real browser) | Medium | Deprioritized |
| LIS + threshold bailout (Opt 4) | Low (after Opt 3) | — | None (real browser) | Medium | Deprioritized |
| Overlap-threshold bailout (Opt 5) | Medium | Potentially high | — | Medium | Hypothesis only |

## Recommended Next Steps

1. **Document S5 as a semantic anti-pattern** in `docs/md/loops.md`: users replacing all
   items with new IDs should not use `key` — it adds overhead with no benefit.

2. **Implement Opt 2** (prefix/suffix sync) for the most common real-world patterns
   (append, prepend, update-in-place). This is the highest-value improvement with moderate effort.

3. **Run a threshold sweep benchmark** for Opt 5 before implementing. The benchmark should
   test overlap = 0%, 10%, 20%, 30%, 50% at n = 50, 200, 500 and identify the threshold
   that minimizes total cost across all overlap levels. Only implement if the data is clear.

4. **Do not implement Opt 3 or Opt 4** — real-browser evidence shows S2 is not a problem
   in production. Adding LIS complexity would be pure overhead.

---

## References

- Vue 3 `patchKeyedChildren` + `getSequence`:
  `packages/runtime-core/src/renderer.ts` (vuejs/core)
- Inferno `patchKeyedChildrenComplex`:
  `packages/inferno/src/DOM/patching.ts` (infernojs/inferno)
- Solid.js `reconcileArrays`:
  `packages/dom-expressions/src/reconcile.ts` (ryansolid/dom-expressions)
- Vershik-Kerov / Logan-Shepp theorem: expected LIS of random permutation ≈ 2√n
- No.JS JSDOM benchmark: `__tests__/loops-benchmark.test.js`
- No.JS real-browser benchmark: `__benchmarks__/keyed-vs-rebuild.bench.spec.ts`
- No.JS implementation: `src/directives/loops.js`, `reconcileItems()` / `reconcileForeachItems()`
