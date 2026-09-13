import { expect } from "@playwright/test";

export const TRANSCRIPT = 'section[aria-label="Transcript"]';
export const STATUS = '[role="status"]';
export const INPUT = 'input[aria-label="Type what you want to say…"]';

export async function openFresh(page, path = "/?simulateAudio=true") {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.goto(path);
}

export async function startConversation(page) {
  await page.getByRole("button", { name: "Start conversation" }).click();
  await expect(page.locator(STATUS).first()).toHaveText(/Listening/);
}

export async function say(page, text) {
  await page.fill(INPUT, text);
  await page.keyboard.press("Enter");
}

export async function waitForSegmentEnd(page) {
  await expect(page.locator(STATUS).first()).toHaveText(/Speaking/);
  await expect(page.locator(STATUS).first()).toHaveText(/Listening/, {
    timeout: 30_000,
  });
}
