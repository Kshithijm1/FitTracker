import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    // Set here (not via shell `NODE_ENV=test npm test`) so `npm test` works
    // identically on Windows cmd/PowerShell and POSIX shells.
    env: { NODE_ENV: "test" },
    setupFiles: ["./test/setup.ts"],
    fileParallelism: false, // tests share one Postgres DB; truncation between tests must not race
  },
});
