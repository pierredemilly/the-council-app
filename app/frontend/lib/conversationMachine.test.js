import { describe, expect, it } from "vitest";
import {
  initialState,
  isReconnecting,
  playableTurn,
  reducer,
} from "~/lib/conversationMachine";

const message = (type, payload, extra = {}) => ({
  protocolVersion: 1,
  type,
  sessionId: "s1",
  eventId: extra.eventId ?? `${type}-${Math.random()}`,
  version: extra.version ?? 1,
  seq: extra.seq ?? 0,
  payload,
});

const started = reducer(initialState, {
  type: "SESSION_STARTED",
  session: { id: "s1", version: 1, lastSeq: 0, config: { agents: [] } },
});

const turn = (id, position, nextAction = null, generationId = "g1") => ({
  id,
  position,
  generationId,
  speaker: "Aphra",
  text: `turn ${position}`,
  nextAction,
});

describe("conversation machine", () => {
  it("hydrates from session.ready and maps created to listening", () => {
    const state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("session.ready", {
        status: "created",
        events: [],
        pendingTurns: [turn("b", 1), turn("a", 0)],
      }),
    });
    expect(state.phase).toBe("listening");
    expect(state.queue.map((t) => t.id)).toEqual(["a", "b"]);
  });

  it("ignores duplicate event ids and stale versions", () => {
    const ready = message("agent.turn.ready", turn("a", 0), {
      eventId: "dup",
      version: 1,
    });
    let state = reducer(started, { type: "SERVER_MESSAGE", message: ready });
    state = reducer(state, { type: "SERVER_MESSAGE", message: ready });
    expect(state.queue).toHaveLength(1);

    const stale = message("agent.turn.ready", turn("old", 0), { version: 0 });
    state = reducer(state, { type: "SERVER_MESSAGE", message: stale });
    expect(state.queue.map((t) => t.id)).toEqual(["a"]);
  });

  it("appends transcript events once, in sequence order", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("transcript.committed", {
        event: { seq: 1, kind: "human", text: "hi" },
      }),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("transcript.committed", {
        event: { seq: 1, kind: "human", text: "hi" },
      }),
    });
    expect(state.events).toHaveLength(1);
    expect(state.lastSeq).toBe(1);
  });

  it("moves turns from the queue to current on playback and clears them on cancel", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("a", 0)),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("b", 1, "wait_for_user")),
    });
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "a" });
    expect(state.current.id).toBe("a");
    expect(state.speaker).toBe("Aphra");
    expect(state.queue.map((t) => t.id)).toEqual(["b"]);

    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.segment.cancel", {}, { version: 2 }),
    });
    expect(state.queue).toEqual([]);
    expect(state.current).toBeNull();
  });

  it("tracks phase, next action and errors from state.changed", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("state.changed", {
        status: "listening",
        nextAction: "yield_to_user",
      }),
    });
    expect(state.nextAction).toBe("yield_to_user");
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("error.recoverable", {
        code: "generation_failed",
        message: "boom",
      }),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("state.changed", { status: "errored" }),
    });
    expect(state.phase).toBe("errored");
    expect(state.error.message).toBe("boom");
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("state.changed", { status: "processing" }),
    });
    expect(state.error).toBeNull();
  });

  it("reports reconnecting only while a live session has no connection", () => {
    expect(isReconnecting(initialState)).toBe(false);
    expect(isReconnecting({ ...started, connection: "disconnected" })).toBe(
      true
    );
    expect(isReconnecting({ ...started, connection: "connected" })).toBe(false);
    expect(isReconnecting({ ...started, phase: "finalized" })).toBe(false);
  });

  it("plays turns strictly in position order even when clips become ready out of order", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("b", 1)),
    });
    expect(playableTurn(state)).toBeNull();
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("a", 0)),
    });
    expect(playableTurn(state).id).toBe("a");
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "a" });
    expect(playableTurn(state)).toBeNull();
    state = reducer(state, { type: "PLAYBACK_FINISHED", turnId: "a" });
    expect(playableTurn(state).id).toBe("b");
  });

  it("drops the previous generation's queue when a new generation starts arriving", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("old", 1, null, "g1")),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("new", 0, null, "g2"), {
        version: 2,
      }),
    });
    expect(state.queue.map((t) => t.id)).toEqual(["new"]);
    expect(playableTurn(state).id).toBe("new");
  });

  it("puts an aborted turn back at the head of the queue so it plays once audio is unlocked", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("a", 0)),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("b", 1)),
    });
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "a" });
    state = reducer(state, { type: "PLAYBACK_ABORTED", turnId: "a" });
    expect(state.current).toBeNull();
    expect(playableTurn(state).id).toBe("a");
  });

  it("holds back turn announcements that crossed a local interruption until the server cancels", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("a", 0)),
    });
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "a" });
    state = reducer(state, { type: "LOCAL_INTERRUPT" });
    expect(state.pendingInterrupt).toBe(true);

    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("b", 1), { version: 1 }),
    });
    expect(state.queue).toEqual([]);

    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.segment.cancel", {}, { version: 2 }),
    });
    expect(state.pendingInterrupt).toBe(false);
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", turn("c", 0, null, "g2"), {
        version: 2,
      }),
    });
    expect(playableTurn(state).id).toBe("c");
  });

  it("highlights the turn playing locally, not a late speaker report from the server", () => {
    let state = reducer(started, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", {
        ...turn("a", 0),
        speaker: "Aphra",
      }),
    });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("agent.turn.ready", {
        ...turn("b", 1),
        speaker: "Rosa",
      }),
    });
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "a" });
    state = reducer(state, { type: "PLAYBACK_FINISHED", turnId: "a" });
    state = reducer(state, { type: "PLAYBACK_STARTED", turnId: "b" });
    state = reducer(state, {
      type: "SERVER_MESSAGE",
      message: message("state.changed", {
        status: "speaking",
        speaker: "Aphra",
      }),
    });
    expect(state.speaker).toBe("Rosa");
  });
});
