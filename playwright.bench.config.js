// @ts-check
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./__benchmarks__",
  testMatch: "**/*.bench.spec.ts",
  timeout: 300_000,
  retries: 0,
  use: {
    headless: true,
    browserName: "chromium",
  },
});
