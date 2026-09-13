import { MicVAD, utils } from "@ricky0123/vad-web";

// Silero v5 processes 512-sample frames at 16 kHz.
export const FRAME_MS = 32;
export const SAMPLE_RATE = 16000;
const ASSET_PATH = "/vad/";

const framesFor = (ms, fallback) =>
  Math.max(1, Math.round((Number.isFinite(ms) ? ms : fallback) / FRAME_MS));

// Maps the admin's VAD settings (probabilities and milliseconds) to the library's frame counts.
export function vadOptions(settings = {}) {
  return {
    positiveSpeechThreshold: settings.positive_speech_threshold ?? 0.5,
    negativeSpeechThreshold: settings.negative_speech_threshold ?? 0.35,
    minSpeechFrames: framesFor(settings.min_speech_ms, 250),
    redemptionFrames: framesFor(settings.redemption_ms, 600),
    preSpeechPadFrames: framesFor(settings.pre_speech_pad_ms, 300),
  };
}

export function encodeUtterance(samples) {
  return new Blob([utils.encodeWAV(samples, 1, SAMPLE_RATE, 1, 16)], {
    type: "audio/wav",
  });
}

// Always-on microphone with echo cancellation; the returned handle is paused/destroyed by the caller.
export async function startMicrophone({
  settings,
  onSpeechStart,
  onSpeechEnd,
  onMisfire,
  onProbability,
}) {
  const vad = await MicVAD.new({
    ...vadOptions(settings),
    model: "v5",
    baseAssetPath: ASSET_PATH,
    onnxWASMBasePath: ASSET_PATH,
    additionalAudioConstraints: {
      echoCancellation: true,
      noiseSuppression: true,
      autoGainControl: true,
    },
    onSpeechStart,
    onVADMisfire: onMisfire,
    onFrameProcessed: onProbability
      ? ({ isSpeech }) => onProbability(isSpeech)
      : undefined,
    onSpeechEnd: (audio) =>
      onSpeechEnd(
        encodeUtterance(audio),
        Math.round((audio.length / SAMPLE_RATE) * 1000)
      ),
  });
  vad.start();
  return vad;
}

// Thresholds change on the running microphone; no restart, no new permission prompt.
export function retuneMicrophone(vad, settings) {
  vad?.setOptions(vadOptions(settings));
}
