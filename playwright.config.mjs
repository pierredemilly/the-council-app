import { defineConfig, devices } from "@playwright/test";

const port = process.env.E2E_PORT || 3100;

// Runs the Rails app in the test environment, on its own database, against the fake providers seeded by `bin/rails e2e:seed`.
export default defineConfig({
  testDir: "./e2e",
  timeout: 60_000,
  expect: { timeout: 15_000 },
  fullyParallel: false,
  workers: 1,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [["github"], ["list"]] : "list",
  use: {
    baseURL: `http://localhost:${port}`,
    ...devices["Desktop Chrome"],
    permissions: ["microphone"],
    launchOptions: {
      args: [
        "--use-fake-device-for-media-stream",
        "--use-fake-ui-for-media-stream",
        "--autoplay-policy=no-user-gesture-required",
      ],
    },
    trace: "retain-on-failure",
  },
  webServer: {
    command: `bin/rails db:prepare && bin/rails e2e:seed && bin/rails server -e test -p ${port}`,
    url: `http://localhost:${port}/up`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
    env: { RAILS_ENV: "test", TEST_DATABASE: "the_council_e2e" },
  },
});
