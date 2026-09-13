// Stage cues such as [laughs] are voiced by the TTS but never shown; drop them and their timings together.
const CUE = /\[[^\]]*\]/g;
const OPENS_CUE = /\[[^\]]*$/;
const HAS_LETTERS = /[\p{L}\p{N}]/u;

function stripCues(word, inCue) {
  let rest = word.replace(CUE, "");
  if (inCue) {
    const close = rest.indexOf("]");
    rest = close === -1 ? "" : rest.slice(close + 1);
    inCue = close === -1;
  }
  if (OPENS_CUE.test(rest)) {
    rest = rest.replace(OPENS_CUE, "");
    inCue = true;
  }
  return { rest, inCue };
}

export function displayWords(text, timings) {
  const words = text.split(/\s+/).filter(Boolean);
  const aligned = timings?.length === words.length ? timings : null;
  const kept = [];
  let inCue = false;
  words.forEach((word, index) => {
    const stripped = stripCues(word, inCue);
    inCue = stripped.inCue;
    if (!HAS_LETTERS.test(stripped.rest)) return;
    kept.push({ word: stripped.rest, timing: aligned ? aligned[index] : null });
  });
  return kept;
}

export function displayText(text) {
  return displayWords(text)
    .map(({ word }) => word)
    .join(" ");
}
