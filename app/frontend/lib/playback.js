// Web Audio playback of one clip at a time with precise position reporting and hard stops.
// The AudioContext must be created from a user gesture (unlock) because of autoplay rules.
const UNLOCK_TIMEOUT_MS = 1500;

export default class AudioPlayer {
  constructor() {
    this.context = null;
    this.buffers = new Map();
    this.pending = new Map();
    this.active = null;
  }

  // resume() never settles on some devices without an output, so never wait on it for long.
  async unlock() {
    this.context ||= new (window.AudioContext || window.webkitAudioContext)();
    if (this.context.state === "suspended") {
      await Promise.race([
        this.context.resume(),
        new Promise((r) => setTimeout(r, UNLOCK_TIMEOUT_MS)),
      ]);
    }
    return this.context.state === "running";
  }

  get blocked() {
    return !this.context || this.context.state !== "running";
  }

  prefetch(turn, headers) {
    if (!turn.clipUrl || this.buffers.has(turn.id) || this.pending.has(turn.id))
      return;
    const promise = fetch(turn.clipUrl, { headers, credentials: "same-origin" })
      .then((res) =>
        res.ok
          ? res.arrayBuffer()
          : Promise.reject(new Error(`clip ${res.status}`))
      )
      .then((bytes) => this.decode(bytes))
      .then((buffer) => {
        this.buffers.set(turn.id, buffer);
        this.pending.delete(turn.id);
        return buffer;
      })
      .catch((error) => {
        this.pending.delete(turn.id);
        throw error;
      });
    this.pending.set(turn.id, promise);
  }

  async decode(bytes) {
    this.context ||= new (window.AudioContext || window.webkitAudioContext)();
    return this.context.decodeAudioData(bytes);
  }

  async buffer(turn, headers) {
    if (this.buffers.has(turn.id)) return this.buffers.get(turn.id);
    this.prefetch(turn, headers);
    return this.pending.get(turn.id);
  }

  // Resolves with the clip duration once playback has started; onEnded fires only for natural ends.
  async play(turn, headers, onEnded) {
    const buffer = await this.buffer(turn, headers);
    if (!(await this.unlock())) throw new Error("audio-blocked");
    this.stop();
    const source = this.context.createBufferSource();
    source.buffer = buffer;
    source.connect(this.context.destination);
    const active = {
      turnId: turn.id,
      source,
      startedAt: this.context.currentTime,
      durationMs: Math.round(buffer.duration * 1000),
    };
    source.onended = () => {
      if (this.active === active) {
        this.active = null;
        onEnded(active.durationMs);
      }
    };
    this.active = active;
    source.start();
    return active.durationMs;
  }

  position() {
    if (!this.active) return null;
    return {
      turnId: this.active.turnId,
      positionMs: Math.min(
        Math.round((this.context.currentTime - this.active.startedAt) * 1000),
        this.active.durationMs
      ),
      durationMs: this.active.durationMs,
    };
  }

  stop() {
    const active = this.active;
    if (!active) return null;
    const position = this.position();
    this.active = null;
    active.source.onended = null;
    try {
      active.source.stop();
    } catch {
      // already stopped
    }
    return position;
  }

  forget(turnIds) {
    turnIds.forEach((id) => {
      this.buffers.delete(id);
      this.pending.delete(id);
    });
  }
}

// Timer-driven stand-in with the same surface, for kiosks without speakers, CI and headless browsers.
export class SimulatedPlayer {
  constructor() {
    this.active = null;
  }

  async unlock() {
    return true;
  }

  get blocked() {
    return false;
  }

  prefetch() {}

  forget() {}

  async play(turn, _headers, onEnded) {
    this.stop();
    const durationMs = turn.durationMs ?? Math.max(1500, turn.text.length * 55);
    const active = {
      turnId: turn.id,
      startedAt: performance.now(),
      durationMs,
    };
    active.timer = setTimeout(() => {
      if (this.active === active) {
        this.active = null;
        onEnded(durationMs);
      }
    }, durationMs);
    this.active = active;
    return durationMs;
  }

  position() {
    if (!this.active) return null;
    return {
      turnId: this.active.turnId,
      positionMs: Math.min(
        Math.round(performance.now() - this.active.startedAt),
        this.active.durationMs
      ),
      durationMs: this.active.durationMs,
    };
  }

  stop() {
    const active = this.active;
    if (!active) return null;
    const position = this.position();
    clearTimeout(active.timer);
    this.active = null;
    return position;
  }
}
