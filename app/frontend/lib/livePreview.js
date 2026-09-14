// Streams the visitor's speech to a realtime transcription service while they talk,
// so a caption appears before the final upload is transcribed. Preview only: the
// server's own transcription of the uploaded utterance stays the transcript of record.

export const FRAME_RATE = 16000;
const BATCH_FRAMES = 4;
const MIN_COMMIT_MS = 120;
const FAKE_WORD_MS = 220;

export function resampleTo(frame, fromRate, toRate) {
  if (fromRate === toRate) return frame;
  const ratio = fromRate / toRate;
  const out = new Float32Array(Math.round(frame.length / ratio));
  for (let i = 0; i < out.length; i += 1) {
    const position = i * ratio;
    const index = Math.min(Math.floor(position), frame.length - 1);
    const next = Math.min(index + 1, frame.length - 1);
    const t = position - index;
    out[i] = frame[index] * (1 - t) + frame[next] * t;
  }
  return out;
}

export function pcm16Base64(samples) {
  const bytes = new Uint8Array(samples.length * 2);
  const view = new DataView(bytes.buffer);
  samples.forEach((sample, i) =>
    view.setInt16(i * 2, Math.max(-1, Math.min(1, sample)) * 0x7fff, true)
  );
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000)
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(binary);
}

const concat = (frames) => {
  const out = new Float32Array(frames.reduce((n, f) => n + f.length, 0));
  let offset = 0;
  frames.forEach((frame) => {
    out.set(frame, offset);
    offset += frame.length;
  });
  return out;
};

// The service runs its own voice detection so partial text streams in; the local
// end of speech commits whatever the service has not closed yet.
function realtimeStream(preview, { onText, onClosed }) {
  const socket = new WebSocket(preview.url, [
    "realtime",
    `openai-insecure-api-key.${preview.token}`,
  ]);
  const queued = [];
  const items = new Map();
  let open = false;
  let speaking = false;
  let pendingMs = 0;
  let batch = [];

  const sendJson = (message) => {
    const raw = JSON.stringify(message);
    if (open) socket.send(raw);
    else queued.push(raw);
  };
  const text = () => [...items.values()].join(" ").replace(/\s+/g, " ").trim();
  const flush = () => {
    if (!batch.length) return;
    const audio = pcm16Base64(concat(batch));
    batch = [];
    sendJson({ type: "input_audio_buffer.append", audio });
  };

  socket.addEventListener("open", () => {
    open = true;
    queued.splice(0).forEach((raw) => socket.send(raw));
  });
  socket.addEventListener("message", (event) => {
    let message;
    try {
      message = JSON.parse(event.data);
    } catch {
      return;
    }
    switch (message.type) {
      case "conversation.item.input_audio_transcription.delta":
        items.set(
          message.item_id,
          (items.get(message.item_id) ?? "") + (message.delta ?? "")
        );
        onText(text(), { done: false });
        break;
      case "conversation.item.input_audio_transcription.completed":
        items.set(
          message.item_id,
          message.transcript ?? items.get(message.item_id) ?? ""
        );
        onText(text(), { done: !speaking });
        break;
      case "input_audio_buffer.speech_stopped":
      case "input_audio_buffer.committed":
        pendingMs = 0;
        break;
      default:
    }
  });
  socket.addEventListener("close", () => {
    open = false;
    onClosed?.();
  });
  socket.addEventListener("error", () => {});

  return {
    get ready() {
      return [WebSocket.CONNECTING, WebSocket.OPEN].includes(socket.readyState);
    },
    begin() {
      items.clear();
      batch = [];
      pendingMs = 0;
      speaking = true;
    },
    push(frame) {
      if (!speaking) return;
      batch.push(
        resampleTo(frame, FRAME_RATE, preview.sample_rate ?? FRAME_RATE)
      );
      pendingMs += (frame.length / FRAME_RATE) * 1000;
      if (batch.length >= BATCH_FRAMES) flush();
    },
    end() {
      if (!speaking) return;
      speaking = false;
      flush();
      if (pendingMs >= MIN_COMMIT_MS)
        sendJson({ type: "input_audio_buffer.commit" });
      pendingMs = 0;
    },
    cancel() {
      speaking = false;
      batch = [];
      items.clear();
      sendJson({ type: "input_audio_buffer.clear" });
    },
    close() {
      socket.close();
    },
  };
}

// Reveals the fake provider's line word by word so the whole path runs without a key.
function fakeStream(preview, { onText }) {
  const words = (preview.text ?? "").split(/\s+/).filter(Boolean);
  let timer = null;
  let shown = 0;
  const reveal = () => {
    shown = Math.min(shown + 1, words.length);
    onText(words.slice(0, shown).join(" "), { done: false });
    if (shown >= words.length) clearInterval(timer);
  };
  return {
    ready: true,
    begin() {
      clearInterval(timer);
      shown = 0;
      timer = setInterval(reveal, FAKE_WORD_MS);
    },
    push() {},
    end() {
      clearInterval(timer);
      if (shown) onText(words.slice(0, shown).join(" "), { done: true });
    },
    cancel() {
      clearInterval(timer);
      onText("", { done: true });
    },
    close() {
      clearInterval(timer);
    },
  };
}

export function createPreviewStream(preview, callbacks) {
  if (!preview) return null;
  return preview.kind === "fake"
    ? fakeStream(preview, callbacks)
    : realtimeStream(preview, callbacks);
}
