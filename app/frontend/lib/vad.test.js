import { describe, expect, it, vi } from "vitest";

vi.mock("@ricky0123/vad-web", () => ({
  MicVAD: { new: vi.fn() },
  utils: { encodeWAV: vi.fn() },
}));

const { vadOptions } = await import("~/lib/vad");

describe("vadOptions", () => {
  it("converts admin milliseconds into 32 ms frames and keeps probabilities", () => {
    expect(
      vadOptions({
        positive_speech_threshold: 0.7,
        negative_speech_threshold: 0.4,
        min_speech_ms: 320,
        redemption_ms: 640,
        pre_speech_pad_ms: 100,
      })
    ).toEqual({
      positiveSpeechThreshold: 0.7,
      negativeSpeechThreshold: 0.4,
      minSpeechFrames: 10,
      redemptionFrames: 20,
      preSpeechPadFrames: 3,
    });
  });

  it("falls back to the defaults and never drops below one frame", () => {
    expect(vadOptions({ min_speech_ms: 0 })).toMatchObject({
      minSpeechFrames: 1,
      redemptionFrames: 19,
      positiveSpeechThreshold: 0.5,
    });
    expect(vadOptions()).toMatchObject({ preSpeechPadFrames: 9 });
  });
});
