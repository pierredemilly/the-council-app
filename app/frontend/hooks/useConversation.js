import { useCallback, useEffect, useReducer, useRef } from "react";
import { api } from "~/lib/api";
import { subscribeToConversation } from "~/lib/cable";
import { initialState, reducer } from "~/lib/conversationMachine";
import {
  clearStoredSession,
  loadStoredSession,
  storeSession,
} from "~/lib/session";

const HEARTBEAT_MS = 30_000;
const MIN_TURN_MS = 1_500;
const MS_PER_CHAR = 55;

// Until real audio arrives (slice 5), a turn "plays" for a duration proportional to its length.
export const simulatedDurationMs = (text) =>
  Math.max(MIN_TURN_MS, text.length * MS_PER_CHAR);

export default function useConversation({ clientMode }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  const channel = useRef(null);
  const playback = useRef(null);
  const graceTimer = useRef(null);
  const idleTimer = useRef(null);
  const stateRef = useRef(state);
  stateRef.current = state;

  const send = useCallback(
    (type, payload) => channel.current?.send(type, payload),
    []
  );

  const disconnect = useCallback(() => {
    channel.current?.close();
    channel.current = null;
    if (playback.current) clearTimeout(playback.current.timer);
    playback.current = null;
    clearTimeout(graceTimer.current);
    clearTimeout(idleTimer.current);
  }, []);

  const connect = useCallback(
    (session) => {
      disconnect();
      channel.current = subscribeToConversation({
        sessionId: session.id,
        token: session.token,
        onMessage: (message) => dispatch({ type: "SERVER_MESSAGE", message }),
        onConnection: (status) => dispatch({ type: "CONNECTION", status }),
        onRejected: () => {
          clearStoredSession();
          disconnect();
          dispatch({ type: "RESET" });
        },
      });
    },
    [disconnect]
  );

  const start = useCallback(async () => {
    const { session } = await api.post("/api/sessions", { clientMode });
    storeSession(session);
    dispatch({ type: "SESSION_STARTED", session });
    connect(session);
  }, [clientMode, connect]);

  const leave = useCallback(() => {
    clearStoredSession();
    disconnect();
    dispatch({ type: "RESET" });
  }, [disconnect]);

  // Resume a recent session on load.
  useEffect(() => {
    const stored = loadStoredSession();
    if (!stored) return undefined;
    let cancelled = false;
    fetch(`/api/sessions/${stored.id}`, {
      headers: { Accept: "application/json", "X-Session-Token": stored.token },
    })
      .then((res) => (res.ok ? res.json() : Promise.reject(res)))
      .then(({ session }) => {
        if (cancelled || session.status === "finalized")
          return clearStoredSession();
        const full = { ...session, token: stored.token };
        storeSession(full);
        dispatch({ type: "SESSION_STARTED", session: full });
        connect(full);
      })
      .catch(() => clearStoredSession());
    return () => {
      cancelled = true;
    };
  }, [connect]);

  useEffect(() => () => disconnect(), [disconnect]);

  const interrupt = useCallback(() => {
    const playing = playback.current;
    clearTimeout(graceTimer.current);
    if (playing) {
      clearTimeout(playing.timer);
      playback.current = null;
      send("speech.started", {
        turnId: playing.turnId,
        positionMs: Math.round(performance.now() - playing.startedAt),
        durationMs: playing.durationMs,
      });
    } else if (["speaking", "processing"].includes(stateRef.current.phase)) {
      send("speech.started", {});
    }
    dispatch({ type: "LOCAL_INTERRUPT" });
  }, [send]);

  const speak = useCallback(
    async (text) => {
      const session = stateRef.current.session;
      if (!session) return;
      if (playback.current || stateRef.current.phase === "speaking")
        interrupt();
      clearTimeout(graceTimer.current);
      await fetch(`/api/sessions/${session.id}/utterances`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-Session-Token": session.token,
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
        body: JSON.stringify({ text }),
      }).then((res) =>
        res.ok
          ? res.json()
          : res.json().then((data) => Promise.reject(new Error(data.error)))
      );
    },
    [interrupt]
  );

  const retry = useCallback(() => {
    dispatch({ type: "CLEAR_ERROR" });
    send("turn.request", {});
  }, [send]);

  // Sequential text-mode playback of the ready turns.
  useEffect(() => {
    if (state.current || playback.current || state.queue.length === 0) return;
    if (!["processing", "speaking"].includes(state.phase)) return;
    const turn = state.queue[0];
    const durationMs = simulatedDurationMs(turn.text);
    dispatch({ type: "PLAYBACK_STARTED", turnId: turn.id });
    send("playback.started", { turnId: turn.id });
    playback.current = {
      turnId: turn.id,
      startedAt: performance.now(),
      durationMs,
      timer: setTimeout(() => {
        playback.current = null;
        send("playback.completed", { turnId: turn.id, spokenMs: durationMs });
        dispatch({ type: "PLAYBACK_FINISHED", turnId: turn.id });
      }, durationMs),
    };
  }, [state.current, state.queue, state.phase, send]);

  // Natural opening: give the visitor a moment, then let the characters carry on.
  useEffect(() => {
    clearTimeout(graceTimer.current);
    if (state.phase !== "listening" || state.nextAction !== "yield_to_user")
      return undefined;
    const grace = state.config?.yield_grace_ms ?? 2500;
    graceTimer.current = setTimeout(() => send("turn.request", {}), grace);
    return () => clearTimeout(graceTimer.current);
  }, [state.phase, state.nextAction, state.config, send]);

  // Kiosk: reset an idle conversation after the configured inactivity window.
  useEffect(() => {
    clearTimeout(idleTimer.current);
    if (clientMode !== "kiosk" || !state.session || state.phase !== "listening")
      return undefined;
    const seconds = state.config?.inactivity_reset_seconds ?? 300;
    idleTimer.current = setTimeout(
      () => send("session.idle_reset", {}),
      seconds * 1000
    );
    return () => clearTimeout(idleTimer.current);
  }, [
    clientMode,
    state.session,
    state.phase,
    state.events.length,
    state.config,
    send,
  ]);

  useEffect(() => {
    if (!state.session || state.connection !== "connected") return undefined;
    const timer = setInterval(() => send("client.heartbeat", {}), HEARTBEAT_MS);
    return () => clearInterval(timer);
  }, [state.session, state.connection, send]);

  useEffect(() => {
    if (state.phase === "finalized") clearStoredSession();
  }, [state.phase]);

  return { state, start, speak, interrupt, retry, leave };
}
