// Stage cues such as [laughs] are voiced by the TTS but never shown; drop them and their timings together.
const CUE = /^\[[^\]]+\]$/;

export function displayWords(text, timings) {
  const words = text.split(/\s+/).filter(Boolean);
  const aligned = timings?.length === words.length ? timings : null;
  const kept = [];
  words.forEach((word, index) => {
    if (CUE.test(word)) return;
    kept.push({ word, timing: aligned ? aligned[index] : null });
  });
  return kept;
}

export function displayText(text) {
  return displayWords(text)
    .map(({ word }) => word)
    .join(" ");
}
