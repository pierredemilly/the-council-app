import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { SimulatedPlayer } from "~/lib/playback";

describe("SimulatedPlayer", () => {
  beforeEach(() =>
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout", "performance"] })
  );
  afterEach(() => vi.useRealTimers());

  it("pauses and resumes without losing the remaining duration", async () => {
    const player = new SimulatedPlayer();
    const ended = vi.fn();
    const duration = await player.play(
      { id: "t", text: "x".repeat(40) },
      {},
      ended
    );
    expect(duration).toBe(2200);

    vi.advanceTimersByTime(1000);
    player.pause();
    vi.advanceTimersByTime(5000);
    expect(ended).not.toHaveBeenCalled();
    expect(player.position().positionMs).toBe(1000);

    player.resume();
    vi.advanceTimersByTime(1199);
    expect(ended).not.toHaveBeenCalled();
    vi.advanceTimersByTime(2);
    expect(ended).toHaveBeenCalledWith(2200);
    expect(player.position()).toBeNull();
  });

  it("stop reports the position reached and silences the end callback", async () => {
    const player = new SimulatedPlayer();
    const ended = vi.fn();
    await player.play({ id: "t", text: "hello there" }, {}, ended);
    vi.advanceTimersByTime(500);
    expect(player.stop()).toMatchObject({
      turnId: "t",
      positionMs: 500,
      durationMs: 1500,
    });
    vi.advanceTimersByTime(5000);
    expect(ended).not.toHaveBeenCalled();
  });
});
