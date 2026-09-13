import { describe, expect, it } from "vitest";
import { displayText, displayWords } from "~/lib/captions";

describe("captions", () => {
  it("drops bracketed stage cues from the displayed text", () => {
    expect(displayText("[laughs] Let them speak. [pause] Well?")).toBe(
      "Let them speak. Well?"
    );
  });

  it("keeps word timings aligned after removing cues", () => {
    const timings = [
      { word: "[laughs]", start_ms: 0, end_ms: 10 },
      { word: "Let", start_ms: 10, end_ms: 300 },
      { word: "them", start_ms: 300, end_ms: 500 },
    ];
    expect(displayWords("[laughs] Let them", timings)).toEqual([
      { word: "Let", timing: timings[1] },
      { word: "them", timing: timings[2] },
    ]);
  });

  it("ignores timings that do not line up with the words", () => {
    expect(displayWords("one two", [{ word: "one" }])).toEqual([
      { word: "one", timing: null },
      { word: "two", timing: null },
    ]);
  });
});
