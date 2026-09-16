import { expect, test } from "@playwright/test";
import {
  INPUT,
  STATUS,
  TRANSCRIPT,
  openFresh,
  say,
  startConversation,
  waitForSegmentEnd,
} from "./helpers.mjs";

test("a visitor starts, speaks first and hears the three characters in order", async ({
  page,
}) => {
  await openFresh(page);
  await expect(page.getByText("Aphra")).toBeVisible();
  await startConversation(page);
  await expect(page.getByText("Microphone on")).toBeVisible();

  await say(page, "Good evening, council");
  await waitForSegmentEnd(page);

  const transcript = await page.locator(TRANSCRIPT).innerText();
  const order = ["You", "Aphra", "Rosa", "Claudia"].map((name) =>
    transcript.indexOf(name)
  );
  expect(
    order.every((index, i) => index >= 0 && (i === 0 || index > order[i - 1]))
  ).toBe(true);
  expect(transcript).toContain("Good evening, council");
});

test("interrupting mid-line keeps only the heard prefix and the characters react", async ({
  page,
}) => {
  await openFresh(page);
  await startConversation(page);
  await say(page, "Good evening, council");
  await expect(page.locator(STATUS).first()).toHaveText(/Speaking/);
  await page.waitForTimeout(1200);

  await page.getByRole("button", { name: "Interrupt" }).click();
  await expect(page.locator(STATUS).first()).toHaveText(/Listening/);
  await say(page, "Wait, let me finish");

  await expect(page.locator(TRANSCRIPT)).toContainText("cut me off");
  const transcript = await page.locator(TRANSCRIPT).innerText();
  expect(transcript).toContain("…");
  expect(transcript).not.toContain("I have thoughts about that.\n\nRosa");
});

test("reloading resumes the same conversation; a later visit starts a new one", async ({
  page,
}) => {
  await openFresh(page);
  await startConversation(page);
  await say(page, "Remember this line");
  await expect(page.locator(TRANSCRIPT)).toContainText("Remember this line");

  await page.reload();
  await expect(page.locator(TRANSCRIPT)).toContainText("Remember this line");

  await page.evaluate(() => {
    const stored = JSON.parse(localStorage.getItem("council.session"));
    stored.resumeDeadline = new Date(Date.now() - 1000).toISOString();
    localStorage.setItem("council.session", JSON.stringify(stored));
  });
  await page.reload();
  await expect(
    page.getByRole("button", { name: "Start conversation" })
  ).toBeVisible();
});

test("kiosk mode hides the footer and returns to the idle screen after inactivity", async ({
  page,
}) => {
  test.setTimeout(120_000);
  await openFresh(page, "/?simulateAudio=true&kiosk=true");
  await expect(page.getByText("Kiosk mode")).toHaveCount(0);
  await startConversation(page);
  await say(page, "Hello");
  await waitForSegmentEnd(page);

  // The seeded inactivity reset is 30 s; the idle screen follows a few seconds after finalization.
  await expect(page.getByText("This conversation has ended.")).toBeVisible({
    timeout: 50_000,
  });
  await expect(
    page.getByRole("button", { name: "Start conversation" })
  ).toBeVisible({ timeout: 15_000 });
});

test("losing the network shows reconnecting, then recovers without duplicating the transcript", async ({
  page,
  context,
}) => {
  await openFresh(page);
  await startConversation(page);
  await say(page, "Stay with me");
  await waitForSegmentEnd(page);
  const before = await page.locator(TRANSCRIPT).innerText();

  await context.setOffline(true);
  await expect(page.locator(STATUS).first()).toHaveText(/Reconnecting/, {
    timeout: 20_000,
  });
  await expect(page.locator(INPUT)).toBeDisabled();

  await context.setOffline(false);
  await expect(page.locator(STATUS).first()).toHaveText(/Listening/, {
    timeout: 30_000,
  });
  expect(await page.locator(TRANSCRIPT).innerText()).toBe(before);
});

test("a signed-in admin tunes voice detection live and saves it as the default", async ({
  page,
}) => {
  await openFresh(page, "/?simulateAudio=true");
  await expect(
    page.getByRole("button", { name: "Voice detection" })
  ).toHaveCount(0);

  await page.goto("/login");
  await page.fill("input[type=email]", "admin@example.com");
  await page.fill("input[type=password]", "password123");
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page).toHaveURL(/\/admin/);

  await page.goto("/?simulateAudio=true");
  await page.getByRole("button", { name: "Voice detection" }).click();
  const panel = page.getByRole("complementary", {
    name: "Voice detection, live",
  });
  const threshold = panel.locator("input[type=range]").first();
  await expect(threshold).toHaveValue("0.5");
  await threshold.focus();
  for (let i = 0; i < 4; i += 1) await page.keyboard.press("ArrowRight");
  await expect(threshold).toHaveValue("0.7");
  await expect(panel.getByText("Applied here, not saved yet.")).toBeVisible();

  await panel.getByRole("button", { name: "Save as default" }).click();
  await expect(panel.getByText("Saved.")).toBeVisible();
  const config = await (await page.request.get("/api/admin/config")).json();
  expect(config.config.vad_settings.positive_speech_threshold).toBe(0.7);
});

test("a visitor opens the biography of a character that has one", async ({
  page,
}) => {
  await openFresh(page);

  await expect(
    page.getByRole("button", { name: "Read Rosa's biography" })
  ).toHaveCount(0);

  await page.getByRole("button", { name: "Read Aphra's biography" }).click();
  const modal = page.getByRole("dialog", { name: "Aphra" });
  await expect(modal).toContainText("Playwright, poet and spy.");

  await modal.getByRole("button", { name: "Close" }).click();
  await expect(modal).toHaveCount(0);
});
