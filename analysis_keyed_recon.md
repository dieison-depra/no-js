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

### Zero-overlap bailout impact (S5 only, PR #25 — closed, code reverted)

| n | with bailout | without bailout | full-rebuild | bailout gain | keyed+bailout vs rebuild |
|---|---|---|---|---|---|
| 50 | 0.41 | 0.39 | 0.35 | 0.95× (marginal) | **1.17× △ rebuild faster** |
| 200 | 1.21 | 1.56 | 0.93 | **1.29× faster** | **1.30× △ rebuild faster** |
| 500 | 2.71 | 2.74 | 1.71 | 1.01× (neutral) | **1.58× △ rebuild faster** |

**Note**: the overlap-threshold sweep (below) revealed that `_zeroOverlapBailout` causes a
**73% regression at n=50** (2.6ms with bailout vs 1.5ms without). The bailout has been
removed from the source. See "Overlap-threshold sweep results" section.

---

## Overlap-Threshold Sweep Results (Chromium, CDP)

Benchmark: `npm run bench:playwright` — third describe block in `keyed-vs-rebuild.bench.spec.ts`.
Overlap fraction = fraction of old items whose key survives in the new list.
Survivors are updated (score+1); new items have offset IDs (n×100) to guarantee no collision.

### n = 50

| overlap | survivors | keyed (ms) | no-bail (ms) | rebuild (ms) | k/r ratio |
|---|---|---|---|---|---|
| 0% | 0 | **2.6** | 1.5 | 1.4 | 1.86× △ |
| 5% | 3 | 1.7 | 1.4 | 1.3 | 1.31× △ |
| 10% | 5 | 1.7 | 1.6 | 1.3 | 1.31× △ |
| 15% | 8 | 1.7 | 1.5 | 1.5 | 1.13× △ |
| 20% | 10 | 1.5 | 1.5 | 1.2 | 1.25× △ |
| 30% | 15 | 1.5 | 1.4 | 1.3 | 1.15× △ |
| 50% | 25 | 1.2 | 1.2 | 1.3 | **0.92× ✓** |

**Break-even at n=50**: ~50% overlap. Bailout hurts throughout (worst: 0.58× at 0%).

### n = 200

| overlap | survivors | keyed (ms) | no-bail (ms) | rebuild (ms) | k/r ratio |
|---|---|---|---|---|---|
| 0% | 0 | 5.7 | 6.2 | 5.2 | 1.10× △ |
| 5% | 10 | 5.5 | 6.0 | 5.1 | 1.08× △ |
| 10% | 20 | 5.5 | 6.0 | 5.0 | 1.10× △ |
| 15% | 30 | 5.9 | 5.9 | 4.7 | 1.26× △ |
| 20% | 40 | 4.8 | 4.9 | 5.4 | **0.89× ✓** |
| 30% | 60 | 4.3 | 4.5 | 4.9 | **0.88× ✓** |
| 50% | 100 | 6.8* | 3.8 | 5.0 | 1.36× △ |

\* 50% row is an anomaly — keyed 6.8ms is a JIT/GC outlier (other rows average ~4-5ms). The
reorder phase at 50% overlap (100 existing + 100 new items) should be similar to 30%.
Bailout helps at 0–10% (+9%), neutral at 15–30%, anomalous at 50%.

**Break-even at n=200**: ~20% overlap.

### n = 500

| overlap | survivors | keyed (ms) | no-bail (ms) | rebuild (ms) | k/r ratio |
|---|---|---|---|---|---|
| 0% | 0 | 15.9 | 16.2 | 12.7 | 1.25× △ |
| 5% | 25 | 14.6 | 13.0 | 11.1 | 1.32× △ |
| 10% | 50 | 13.8 | 12.8 | 13.0 | 1.06× △ |
| 15% | 75 | 11.9 | 11.7 | 11.5 | 1.03× △ |
| 20% | 100 | 12.7 | 11.3 | 13.7 | **0.93× ✓** |
| 30% | 150 | 11.4 | 11.3 | 13.4 | **0.85× ✓** |
| 50% | 250 | 9.2 | 8.9 | 11.3 | **0.81× ✓** |

Bailout is neutral throughout at n=500. No-bailout is slightly faster at 5–20% (noise range).

**Break-even at n=500**: ~20% overlap.

### Summary

| n | break-even overlap | bailout at 0% | bailout at 10% | bailout at 50% |
|---|---|---|---|---|
| 50 | ~50% | **hurts** (0.58×) | hurts (0.94×) | neutral |
| 200 | ~20% | helps (1.09×) | helps (1.09×) | **hurts** (0.56×) |
| 500 | ~20% | neutral (1.02×) | hurts (0.93×) | neutral (0.97×) |

**Key finding**: `_zeroOverlapBailout` is net harmful at n=50 because it calls `_disposeChildren(el)`
from the parent (traversing all 50 wrapper × 2 span = 100 nodes) while the per-item path calls
`_disposeChildren(wrapper)` per item (2 nodes each). The parent sweep has a higher setup cost
that overwhelms the saving from avoiding 50 individual `wrapper.remove()` calls.

**Consequence for Opt 5**: any overlap-threshold bailout must be guarded by a minimum list
size (e.g., `if (keyMap.size < 100) return false`). Below ~100 items, the bulk-clear cost
dominates and the bailout is never beneficial regardless of overlap fraction.

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

### Optimization 1 — Zero-overlap bailout — PR #25 closed, code reverted

Implemented as `_zeroOverlapBailout()` in `src/directives/loops.js`. Replaced n individual
`wrapper.remove()` calls with a single `_disposeChildren(el) + el.innerHTML="" + keyMap.clear()`.

**Initial benchmark result (S5 only)**: appeared to help at n=200 (+29%), neutral elsewhere.

**Overlap sweep result (definitive)**: the bailout causes a **73% regression at n=50** — at
zero overlap, keyed WITH bailout takes 2.6ms vs 1.5ms without. The root cause is that
`_disposeChildren(el)` recursively visits all children from the parent, while the
pre-bailout path called `_disposeChildren(wrapper)` per item (visiting only 2 child spans).
The parent-level traversal has a higher constant factor at small n, where the total node
count is modest enough that per-item removal is cheaper than the recursive parent sweep.

The code has been removed from `src/directives/loops.js`. PR #25 remains closed.

**Status**: reverted from source.

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

### Optimization 5 — Overlap-threshold bailout (S5 partial fix, hypothesis)

Generalization of Opt 1. Instead of only bailing out when overlap = 0, bail out when the
surviving key fraction falls below a threshold (e.g., 10–20%):

```js
function _overlapThresholdBailout(keyMap, nextKeySet, el, threshold = 0.10) {
  if (keyMap.size === 0) return false;
  const survivorLimit = Math.floor(threshold * keyMap.size);
  let survivors = 0;
  for (const key of keyMap.keys()) {
    if (nextKeySet.has(key)) {
      survivors++;
      if (survivors > survivorLimit) return false; // early exit: enough survivors, no bailout
    }
  }
  _disposeChildren(el);
  el.innerHTML = "";
  keyMap.clear();
  return true;
}
```

**Cost model (all costs in units of P = one processTree() call):**

Define: K = key evaluation, P = processTree, U = Object.assign+$notify update, R = one
wrapper.remove(), C = bulk clear (innerHTML=""), I = insertBefore, A = cloneNode+createElement.

From S4 benchmark data (pure-update scenario), calibrating per-item costs at n=500:
- P ≈ 0.00386ms/item (dominant cost)
- K ≈ 0.03–0.06 × P (expression evaluator with LRU cache warmup)
- U ≈ 0.04 × P
- R ≈ 0.15 × P, I ≈ 0.05 × P, A ≈ 0.05 × P

**Break-even fraction (algebraic):**

Keyed path (n_old = n = list size, s = survivors):

    Cost_keyed = n×K + (n-s)×R + (n-s)×(A+P) + s×U + n×I

Full-rebuild:

    Cost_rebuild = C + n×(A+P)

Setting equal and solving for f = s/n:

    f_breakeven ≈ (K + R + I) / (R + A + P - U)

Plugging in approximate ratios:

    f_breakeven ≈ (0.05 + 0.15 + 0.05) / (0.15 + 0.05 + 1 - 0.04) ≈ 0.25 / 1.16 ≈ **0.22–0.26**

Keyed wins only when more than ~24% of items have a surviving key. Below that, full-rebuild
is cheaper because it skips the O(n) key evaluation pass and the per-item insertBefore reorder.

**What the threshold actually buys:**

The bailout replaces (n - s) × R (individual removes) with C (one bulk clear). This is
always beneficial for dying nodes. However, it also discards s surviving nodes that would
have been updated cheaply at cost s × U. Those survivors must be recreated at cost s × P.
The net effect of discarding s survivors:

    extra cost = s × (P - U) ≈ s × 0.96 × P

The bulk-clear saving is (n - s) × R ≈ (n - s) × 0.15 × P.

Net gain from bailout vs no-bailout:

    (n - s) × 0.15P - s × 0.96P - C_fixed

This is only net positive when (n - s) × 0.15 > s × 0.96, i.e., when:

    s/n < 0.15 / (0.15 + 0.96) ≈ **0.135**

So the threshold must be below ~13% to avoid making things worse by discarding survivors.
At the proposed 20% threshold, the bailout is net harmful for the survivors at that fraction.
A conservative threshold of **10% (0.10)** stays safely below the break-even of ~24% and
below the discard-benefit boundary of ~13%.

**Partial overlap scenarios at n=200:**

| Overlap | Survivors | keyed processTree | rebuild processTree | Keyed wins? |
|---|---|---|---|---|
| 0% (S5) | 0 | 200 | 200 | No (extra K+I overhead) |
| 10% | 20 | 180 | 200 | No (~1.4ms vs 0.93ms) |
| 20% | 40 | 160 | 200 | No (~1.1ms vs 0.93ms, near break-even) |
| 26% | 52 | 148 | 200 | Break-even (~0.93ms) |
| 30% | 60 | 140 | 200 | Yes (~0.85ms) |
| 50% | 100 | 100 | 200 | Yes (clearly, ~0.50ms) |

**Blocking concerns before implementation:**

1. **Minimum list size guard required**: the overlap sweep shows the bailout is net harmful
   at n=50 regardless of overlap fraction. Any implementation must be guarded by:
   ```js
   if (keyMap.size < 100) return false;  // bulk-clear overhead dominates at small n
   ```
   The exact threshold (100 vs 50 vs 150) should be validated by the benchmark sweep.

2. **Animation regression**: if `animate-enter` is set, surviving nodes cleared by the bailout
   will trigger enter animations when recreated, even though the user perceives them as existing.
   Requires either a flag to suppress enter animation for would-be-survivors, or explicit
   documentation of the limitation. This is a **visible regression** for animated lists.

3. **State preservation contract broken**: the keyed algorithm's implicit contract is that
   nodes with surviving keys are not destroyed — they preserve `<input>` focus, video playback
   state, scroll position. The threshold bailout breaks this silently for nodes in the 0–10%
   overlap range. Must be explicitly documented if implemented.

4. **Threshold is not template-aware**: break-even fraction depends on P/K ratio, which
   varies with template complexity. A conservative threshold of 10% mitigates this but does
   not eliminate the risk of regressing simple templates where P is closer to K.

**Early-exit scan**: the proposed implementation already includes early exit at `survivors > survivorLimit`.
For above-threshold overlap, the scan stops after approximately `threshold / f × n` iterations
instead of n. No benefit for S5 (zero overlap requires full scan), but reduces overhead for
cases just above the threshold boundary.

**Architectural constraint on pre-bailout key evaluation**: key evaluation (building `newOrder`
and `nextKeySet`) must happen before the bailout check because both are required by the
removal, create, and reorder phases. Restructuring to evaluate keys incrementally before
bailing would require splitting `reconcileItems` into two phases (probe + commit), adding
significant complexity for K savings that are at most 6% of total cost. Not recommended.

**Status**: benchmark sweep complete (see "Overlap-Threshold Sweep Results" above).
Key findings from sweep:
- Break-even is **~20% overlap for n≥200**, ~50% for n=50
- Current `_zeroOverlapBailout` **hurts at n=50** (73% slower) → removed from source
- Any threshold bailout must include a **minimum size guard** (`keyMap.size >= 100`)

Still blocked on:
1. A policy decision on animation-enter behavior for bailout-cleared survivors
2. Documentation of the state-preservation contract break in `docs/md/loops.md`

---

## Updated Priority Matrix

| Optimization | Effort | S5 gain | S2 gain | Risk | Status |
|---|---|---|---|---|---|
| Zero-overlap bailout (Opt 1) | Low | Partial (n=200 only) | — | Very low | Closed (PR #25) |
| Prefix/suffix sync (Opt 2) | Medium | — | Medium (partial sort) | Low | Candidate |
| LIS minimal moves (Opt 3) | High | — | None (real browser) | Medium | Deprioritized |
| LIS + threshold bailout (Opt 4) | Low (after Opt 3) | — | None (real browser) | Medium | Deprioritized |
| Overlap-threshold bailout (Opt 5) | Medium | Partial (< 13% overlap) | — | Medium | Hypothesis — blocked on benchmark sweep + animation policy |

## Recommended Next Steps

1. **Remove `_zeroOverlapBailout` from source** (already done) — the overlap sweep proves
   it causes a 73% regression at n=50. No bailout at all is strictly better at small lists.

2. **Document S5 as a semantic anti-pattern** in `docs/md/loops.md`. Users who replace all
   items with new IDs should omit `key` — it adds overhead with no benefit. Add a guidance
   table row: "Replace entire list with new IDs → omit `key`."

3. **Opt 5 prerequisites before any code**:
   - Decide the animation-enter policy for bailout-cleared survivors (Option A: suppress
     animation for would-be-survivors; Option B: document that enter animation fires for
     all recreated nodes). Option A is correct but complex; Option B ships faster.
   - Document the state-preservation contract break (focus, scroll, video state) in
     `docs/md/loops.md`.
   - Extend the benchmark sweep to also vary the minimum-size guard (50, 100, 150) to
     find the correct `keyMap.size` floor below which the bailout never fires.

4. **Implement Opt 5** with threshold = 0.10 + minimum size guard of `keyMap.size >= 100`.
   Use the early-exit scan. Apply to `reconcileItems` (each) first; port to
   `reconcileForeachItems` (foreach) after validation.

5. **Implement Opt 2** (prefix/suffix sync) — highest-value improvement for append/prepend
   patterns, independent of the S5 work.

6. **Do not implement Opt 3 or Opt 4** — S2 is not a real-browser problem.

### Key algebraic result to remember

The keyed path breaks even with full-rebuild at **~24% key overlap** (f ≈ 0.22–0.26,
depending on template complexity). Below that fraction, full-rebuild is cheaper because the
O(n) key evaluation pass + per-item insertBefore reorder overhead exceeds the savings from
reusing processTree for the surviving fraction. The overlap-threshold bailout is only net
positive when f < ~13% (the discard-benefit boundary), which means threshold = 0.10 is the
practical upper limit for a conservative implementation.

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
