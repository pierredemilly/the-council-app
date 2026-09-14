import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  createPreviewStream,
  pcm16Base64,
  resampleTo,
} from "~/lib/livePreview";

class FakeSocket {
  static instances = [];
  constructor(url, protocols) {
    this.url = url;
    this.protocols = protocols;
    this.sent = [];
    this.listeners = {};
    this.readyState = FakeSocket.CONNECTING;
    FakeSocket.instances.push(this);
  }
  addEventListener(type, fn) {
    this.listeners[type] = fn;
  }
  send(raw) {
    this.sent.push(JSON.parse(raw));
  }
  close() {
    this.readyState = FakeSocket.CLOSED;
    this.listeners.close?.();
  }
  open() {
    this.readyState = FakeSocket.OPEN;
    this.listeners.open?.();
  }
  receive(message) {
    this.listeners.message?.({ data: JSON.stringify(message) });
  }
}
FakeSocket.CONNECTING = 0;
FakeSocket.OPEN = 1;
FakeSocket.CLOSED = 3;

const frame = (value = 0.5, length = 512) =>
  new Float32Array(length).fill(value);

describe("audio conversion", () => {
  it("resamples 16 kHz frames to 24 kHz by interpolation", () => {
    const out = resampleTo(new Float32Array([0, 1, 0, -1]), 16000, 24000);
    expect(out.length).toBe(6);
    expect(Array.from(out).map((v) => Number(v.toFixed(3)))).toEqual([
      0, 0.667, 0.667, 0, -0.667, -1,
    ]);
  });

  it("encodes little-endian 16-bit PCM as base64 and clips out-of-range samples", () => {
    const bytes = Uint8Array.from(
      atob(pcm16Base64(new Float32Array([0, 1, -2]))),
      (c) => c.charCodeAt(0)
    );
    const view = new DataView(bytes.buffer);
    expect([
      view.getInt16(0, true),
      view.getInt16(2, true),
      view.getInt16(4, true),
    ]).toEqual([0, 32767, -32767]);
  });
});

describe("realtime preview stream", () => {
  beforeEach(() => {
    FakeSocket.instances = [];
    vi.stubGlobal("WebSocket", FakeSocket);
  });
  afterEach(() => vi.unstubAllGlobals());

  const preview = {
    kind: "openai_realtime",
    url: "wss://example.test/realtime",
    token: "ek_test",
    sample_rate: 24000,
  };

  it("authenticates with the ephemeral key and streams batched audio once open", () => {
    const onText = vi.fn();
    const stream = createPreviewStream(preview, { onText });
    const socket = FakeSocket.instances[0];
    expect(socket.protocols).toEqual([
      "realtime",
      "openai-insecure-api-key.ek_test",
    ]);

    stream.begin();
    for (let i = 0; i < 4; i += 1) stream.push(frame());
    expect(socket.sent).toEqual([]);
    socket.open();
    expect(socket.sent).toHaveLength(1);
    expect(socket.sent[0].type).toBe("input_audio_buffer.append");
    expect(atob(socket.sent[0].audio).length).toBe(4 * 768 * 2);
  });

  it("accumulates deltas per item, commits at the end of local speech and reports the final text", () => {
    const onText = vi.fn();
    const stream = createPreviewStream(preview, { onText });
    const socket = FakeSocket.instances[0];
    socket.open();
    stream.begin();
    for (let i = 0; i < 8; i += 1) stream.push(frame());
    socket.receive({
      type: "conversation.item.input_audio_transcription.delta",
      item_id: "a",
      delta: "Good",
    });
    socket.receive({
      type: "conversation.item.input_audio_transcription.delta",
      item_id: "a",
      delta: " evening",
    });
    expect(onText).toHaveBeenLastCalledWith("Good evening", { done: false });

    stream.end();
    expect(socket.sent.at(-1)).toEqual({ type: "input_audio_buffer.commit" });
    socket.receive({
      type: "conversation.item.input_audio_transcription.completed",
      item_id: "a",
      transcript: "Good evening.",
    });
    expect(onText).toHaveBeenLastCalledWith("Good evening.", { done: true });
  });

  it("skips the commit when the service already closed the turn and clears on a misfire", () => {
    const onText = vi.fn();
    const stream = createPreviewStream(preview, { onText });
    const socket = FakeSocket.instances[0];
    socket.open();
    stream.begin();
    for (let i = 0; i < 8; i += 1) stream.push(frame());
    socket.receive({ type: "input_audio_buffer.speech_stopped" });
    stream.end();
    expect(socket.sent.map((m) => m.type)).not.toContain(
      "input_audio_buffer.commit"
    );

    stream.begin();
    stream.cancel();
    expect(socket.sent.at(-1)).toEqual({ type: "input_audio_buffer.clear" });
  });

  it("reports closure so the caller can fetch a fresh key", () => {
    const onClosed = vi.fn();
    const stream = createPreviewStream(preview, { onText: vi.fn(), onClosed });
    expect(stream.ready).toBe(true);
    FakeSocket.instances[0].close();
    expect(onClosed).toHaveBeenCalled();
    expect(stream.ready).toBe(false);
  });
});

describe("fake preview stream", () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it("reveals the configured line word by word while speaking", () => {
    const onText = vi.fn();
    const stream = createPreviewStream(
      { kind: "fake", text: "Hello from the fake microphone" },
      { onText }
    );
    stream.begin();
    vi.advanceTimersByTime(450);
    expect(onText).toHaveBeenLastCalledWith("Hello from", { done: false });
    stream.end();
    expect(onText).toHaveBeenLastCalledWith("Hello from", { done: true });
    vi.advanceTimersByTime(2000);
    expect(onText).toHaveBeenCalledTimes(3);
  });
});
