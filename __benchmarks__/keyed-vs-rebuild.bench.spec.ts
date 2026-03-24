// ═══════════════════════════════════════════════════════════════════════════
//  keyed-vs-rebuild.bench.spec.js
//
//  Playwright/Chromium CDP benchmark: keyed reconciliation vs full-rebuild
//  in a real browser with layout, JIT, and processTree() cost included.
//
//  Run: npx playwright test --config playwright.bench.config.js
//
//  Why this exists:
//    The JSDOM benchmark (loops-benchmark.test.js) cannot capture real
//    browser costs: insertBefore in JSDOM is a pure linked-list op with no
//    layout recalculation, and processTree() is far cheaper without CSS
//    computation or property access side-effects.
//    This benchmark runs the same scenarios in Chromium via CDP so the
//    numbers reflect production conditions.
//
//  Scenarios:
//    S1 — push:    append one item at end
//    S2 — reverse: full sort reversal (worst case for keyed reorder)
//    S3 — splice:  remove one item from the middle
//    S4 — update:  same keys, all item data changed (in-place update)
//    S5 — replace: all new IDs, zero key overlap (worst case for keyed removal)
//
//  List sizes: 50, 200, 500
//  Runs per cell: 7  (first 2 discarded as JIT warmup)
//
//  Metrics per scenario×size×strategy:
//    - wall-clock time (performance.now() inside browser, synchronous)
//    - ScriptDuration delta (CDP Performance.getMetrics)
//    - DOM Nodes delta (CDP)
//    - JS heap delta (CDP)
// ═══════════════════════════════════════════════════════════════════════════

import { test } from "@playwright/test";
import { readFileSync } from "fs";
import { resolve } from "path";

const IIFE_SOURCE = readFileSync(
  resolve(process.cwd(), "dist/iife/no.js"),
  "utf8"
);

const RUNS = 7;
const WARMUP = 2;
const SIZES = [50, 200, 500];

// ─── Data helpers (run in Node, passed into browser) ─────────────────────────

function makeItems(n, offset = 0) {
  return Array.from({ length: n }, (_, i) => ({
    id: offset + i + 1,
    name: `item-${offset + i + 1}`,
    score: ((offset + i + 1) * 7) % 100,
  }));
}

// ─── Scenario definitions ─────────────────────────────────────────────────────

function buildScenarios(n) {
  const base = makeItems(n);
  return {
    S1_push: {
      label: "push (append 1)",
      before: base,
      after: [...base, { id: n + 9999, name: `item-new`, score: 42 }],
    },
    S2_reverse: {
      label: "reverse (full sort)",
      before: base,
      after: [...base].reverse(),
    },
    S3_splice: {
      label: "splice (remove middle)",
      before: base,
      after: base.filter((_, i) => i !== Math.floor(n / 2)),
    },
    S4_update: {
      label: "update (same keys, new data)",
      before: base,
      after: base.map((item) => ({ ...item, score: item.score + 1, name: item.name + "!" })),
    },
    S5_replace: {
      label: "replace (zero key overlap)",
      before: base,
      after: makeItems(n, n * 10),
    },
  };
}

// ─── Page setup ───────────────────────────────────────────────────────────────

async function setupPage(page, initialItems) {
  // Two independent state trees: one keyed, one full-rebuild.
  // Identical initial data so comparison is fair.
  const stateJson = JSON.stringify({ items: initialItems });

  await page.setContent(`<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
  <template id="bench-tpl">
    <div class="row">
      <span class="name" bind="item.name"></span>
      <span class="score" bind="item.score"></span>
    </div>
  </template>

  <!-- Keyed list -->
  <div id="ks" state='${stateJson}'>
    <div id="kl" each="item in items" template="bench-tpl" key="item.id"></div>
  </div>

  <!-- Full-rebuild list (no key attribute) -->
  <div id="rs" state='${stateJson}'>
    <div id="rl" each="item in items" template="bench-tpl"></div>
  </div>
</body>
</html>`);

  await page.addScriptTag({ content: IIFE_SOURCE });

  // Wait for both lists to be populated.
  await page.waitForFunction(
    (n) =>
      document.getElementById("kl")?.children.length === n &&
      document.getElementById("rl")?.children.length === n,
    initialItems.length
  );
}

// ─── CDP helpers ─────────────────────────────────────────────────────────────

async function getCDPMetrics(page) {
  const client = await page.context().newCDPSession(page);
  await client.send("Performance.enable");
  const { metrics } = await client.send("Performance.getMetrics");
  await client.detach();
  const m = Object.fromEntries(metrics.map((x) => [x.name, x.value]));
  return {
    scriptDuration: m.ScriptDuration ?? 0,
    nodes: m.Nodes ?? 0,
    heap: m.JSHeapUsedSize ?? 0,
  };
}

async function forceGC(page) {
  const client = await page.context().newCDPSession(page);
  await client.send("HeapProfiler.collectGarbage");
  await client.detach();
}

// ─── Core timing ─────────────────────────────────────────────────────────────

/**
 * Runs `RUNS` iterations of a state mutation on one context inside the
 * browser and returns the raw wall-clock times (ms) from performance.now().
 * The first `WARMUP` samples are discarded before computing stats.
 */
async function timeOperation(page, ctxId, beforeItems, afterItems) {
  const samples = await page.evaluate(
    ({ ctxId, beforeItems, afterItems, RUNS, WARMUP }) => {
      const el = document.getElementById(ctxId);
      const ctx = el?.__ctx;
      if (!ctx) return [];

      const times = [];
      for (let i = 0; i < RUNS; i++) {
        // Reset to before state.
        ctx.__raw.items = JSON.parse(JSON.stringify(beforeItems));
        ctx.$notify();

        // Measure the operation.
        const t0 = performance.now();
        ctx.__raw.items = JSON.parse(JSON.stringify(afterItems));
        ctx.$notify();
        times.push(performance.now() - t0);
      }
      return times.slice(WARMUP);
    },
    { ctxId: ctxId, beforeItems, afterItems, RUNS, WARMUP }
  );
  return samples;
}

function stats(samples) {
  if (!samples.length) return { avg: 0, min: 0, max: 0, median: 0 };
  const sorted = [...samples].sort((a, b) => a - b);
  const avg = samples.reduce((s, v) => s + v, 0) / samples.length;
  return {
    avg: +avg.toFixed(3),
    min: +sorted[0].toFixed(3),
    max: +sorted[sorted.length - 1].toFixed(3),
    median: +sorted[Math.floor(sorted.length / 2)].toFixed(3),
  };
}

function ratio(keyed, rebuild) {
  if (rebuild === 0) return "—";
  const r = keyed / rebuild;
  return r.toFixed(2) + "x " + (r <= 1 ? "✓ keyed faster" : "△ rebuild faster");
}

// ─── Tests ───────────────────────────────────────────────────────────────────

test.describe("Keyed reconciliation vs full-rebuild — real browser (Chromium)", () => {
  test.skip(
    ({ browserName }) => browserName !== "chromium",
    "CDP metrics require Chromium"
  );

  for (const n of SIZES) {
    test(`n=${n} — all scenarios`, async ({ page }) => {
      test.setTimeout(120_000);

      const scenarios = buildScenarios(n);
      const results = [];

      console.log(`\n${"═".repeat(72)}`);
      console.log(`  No.JS — keyed vs full-rebuild benchmark  (n=${n}, real Chromium)`);
      console.log(`${"═".repeat(72)}`);
      console.log(
        `  ${"Scenario".padEnd(30)} ${"Strategy".padEnd(10)} ${"avg ms".padStart(8)} ${"min".padStart(8)} ${"max".padStart(8)} ${"median".padStart(8)}`
      );
      console.log(`  ${"-".repeat(70)}`);

      for (const [key, scenario] of Object.entries(scenarios)) {
        await setupPage(page, scenario.before);

        // Measure keyed.
        const keyedSamples = await timeOperation(
          page, "ks", scenario.before, scenario.after
        );
        const keyedStats = stats(keyedSamples);

        // Measure rebuild.
        const rebuildSamples = await timeOperation(
          page, "rs", scenario.before, scenario.after
        );
        const rebuildStats = stats(rebuildSamples);

        // CDP bulk metrics for keyed (single run after warmup).
        await forceGC(page);
        const beforeCDP = await getCDPMetrics(page);
        await page.evaluate(
          ({ beforeItems, afterItems }) => {
            const ctx = document.getElementById("ks")?.__ctx;
            if (!ctx) return;
            ctx.__raw.items = JSON.parse(JSON.stringify(beforeItems));
            ctx.$notify();
            ctx.__raw.items = JSON.parse(JSON.stringify(afterItems));
            ctx.$notify();
          },
          { beforeItems: scenario.before, afterItems: scenario.after }
        );
        const afterCDP = await getCDPMetrics(page);

        const cdp = {
          scriptDeltaMs: +((afterCDP.scriptDuration - beforeCDP.scriptDuration) * 1000).toFixed(3),
          nodesDelta: afterCDP.nodes - beforeCDP.nodes,
          heapDeltaKB: +(((afterCDP.heap - beforeCDP.heap) / 1024)).toFixed(1),
        };

        results.push({
          scenario: scenario.label,
          n,
          keyed: keyedStats,
          rebuild: rebuildStats,
          cdp,
        });

        console.log(
          `  ${scenario.label.padEnd(30)} ${"keyed".padEnd(10)} ${String(keyedStats.avg).padStart(8)} ${String(keyedStats.min).padStart(8)} ${String(keyedStats.max).padStart(8)} ${String(keyedStats.median).padStart(8)}`
        );
        console.log(
          `  ${"".padEnd(30)} ${"rebuild".padEnd(10)} ${String(rebuildStats.avg).padStart(8)} ${String(rebuildStats.min).padStart(8)} ${String(rebuildStats.max).padStart(8)} ${String(rebuildStats.median).padStart(8)}`
        );
        console.log(
          `  ${"".padEnd(30)} ${"ratio".padEnd(10)} ${ratio(keyedStats.median, rebuildStats.median).padStart(34)}`
        );
        console.log(
          `  ${"".padEnd(30)} ${"cdp".padEnd(10)} script Δ${String(cdp.scriptDeltaMs).padStart(6)}ms  nodes Δ${String(cdp.nodesDelta).padStart(5)}  heap Δ${String(cdp.heapDeltaKB).padStart(7)}KB`
        );
        console.log(`  ${"-".repeat(70)}`);
      }

      // Summary table.
      console.log(`\n  SUMMARY (n=${n}, median ms — lower is better)`);
      console.log(`  ${"Scenario".padEnd(30)} ${"keyed".padStart(10)} ${"rebuild".padStart(10)} ${"ratio".padStart(20)}`);
      console.log(`  ${"-".repeat(72)}`);
      for (const r of results) {
        console.log(
          `  ${r.scenario.padEnd(30)} ${String(r.keyed.median).padStart(10)} ${String(r.rebuild.median).padStart(10)} ${ratio(r.keyed.median, r.rebuild.median).padStart(20)}`
        );
      }
      console.log(`${"═".repeat(72)}\n`);
    });
  }
});
