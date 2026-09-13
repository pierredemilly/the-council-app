import { useCallback, useEffect, useReducer, useRef, useState } from "react";
import { api } from "~/lib/api";
import { subscribeToConversation } from "~/lib/cable";
import { initialState, playableTurn, reducer } from "~/lib/conversationMachine";
import AudioPlayer, { SimulatedPlayer } from "~/lib/playback";
import { startMicrophone } from "~/lib/vad";
import { readFlag } from "~/hooks/useQueryFlag";
import {
  clearStoredSession,
  loadStoredSession,
  storeSession,
} from "~/lib/session";

const HEARTBEAT_MS = 30_000;
const PROGRESS_MS = 1_000;
const CAPTION_MS = 100;

export default function useConversation({ clientMode }) {
  const [state, dispatch] = useReducer(reducer, initialState);
  const [positionMs, setPositionMs] = useState(0);
  const [audioBlocked, setAudioBlocked] = useState(false);
  const [micState, setMicState] = useState("off");
  const [userSpeaking, setUserSpeaking] = useState(false);
  const mic = useRef(null);
  const interruptTimer = useRef(null);
  const interruptedByVoice = useRef(false);
  const channel = useRef(null);
  const player = useRef(null);
  const graceTimer = useRef(null);
  const idleTimer = useRef(null);
  const stateRef = useRef(state);
  stateRef.current = state;
  // ?simulateAudio=true keeps the whole loop testable on machines without an audio output.
  player.current ||= readFlag("simulateAudio")
    ? new SimulatedPlayer()
    : new AudioPlayer();

  const send = useCallback(
    (type, payload) => channel.current?.send(type, payload),
    []
  );

  const authHeaders = useCallback(() => {
    const session = stateRef.current.session;
    return session ? { "X-Session-Token": session.token } : {};
  }, []);

  const stopMicrophone = useCallback(() => {
    clearTimeout(interruptTimer.current);
    mic.current?.destroy();
    mic.current = null;
    setMicState("off");
    setUserSpeaking(false);
  }, []);

  const disconnect = useCallback(() => {
    channel.current?.close();
    channel.current = null;
    player.current.stop();
    stopMicrophone();
    clearTimeout(graceTimer.current);
    clearTimeout(idleTimer.current);
  }, [stopMicrophone]);

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

  const unlockAudio = useCallback(async () => {
    const ok = await player.current.unlock().catch(() => false);
    setAudioBlocked(!ok);
    return ok;
  }, []);

  const interrupt = useCallback(() => {
    clearTimeout(graceTimer.current);
    const stopped = player.current.stop();
    if (stopped) {
      send("speech.started", stopped);
    } else if (["speaking", "processing"].includes(stateRef.current.phase)) {
      send("speech.started", {});
    }
    player.current.forget(stateRef.current.queue.map((t) => t.id));
    dispatch({ type: "LOCAL_INTERRUPT" });
  }, [send]);

  const uploadUtterance = useCallback(
    async (blob) => {
      const session = stateRef.current.session;
      if (!session) return;
      const body = new FormData();
      body.append("audio", blob, "utterance.wav");
      const res = await fetch(`/api/sessions/${session.id}/utterances`, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-Session-Token": session.token,
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
            ?.content,
        },
        body,
      });
      if (res.ok) return;
      const data = await res.json().catch(() => ({}));
      // Nothing usable was said: pick the conversation back up instead of leaving a silence.
      if (data.code === "no_speech" && interruptedByVoice.current)
        send("turn.request", {});
      if (data.code === "transcription_failed")
        dispatch({
          type: "SERVER_MESSAGE",
          message: {
            protocolVersion: 1,
            type: "error.recoverable",
            version: stateRef.current.version,
            payload: { code: data.code, message: data.error, retryable: true },
          },
        });
    },
    [send]
  );

  // Voice activity: pause the speaker at once, treat sustained speech as an interruption.
  const handleSpeechStart = useCallback(() => {
    setUserSpeaking(true);
    clearTimeout(graceTimer.current);
    interruptedByVoice.current = false;
    if (player.current.position()) {
      player.current.pause();
      const debounce =
        stateRef.current.config?.vad_settings?.interrupt_min_speech_ms ?? 300;
      interruptTimer.current = setTimeout(() => {
        interruptedByVoice.current = true;
        interrupt();
      }, debounce);
    }
  }, [interrupt]);

  const handleMisfire = useCallback(() => {
    clearTimeout(interruptTimer.current);
    setUserSpeaking(false);
    player.current.resume();
  }, []);

  const handleSpeechEnd = useCallback(
    (blob) => {
      clearTimeout(interruptTimer.current);
      setUserSpeaking(false);
      if (player.current.position()) {
        interruptedByVoice.current = true;
        interrupt();
      }
      send("speech.ended", {});
      uploadUtterance(blob);
    },
    [interrupt, send, uploadUtterance]
  );

  const startMic = useCallback(async () => {
    if (mic.current) return;
    setMicState("starting");
    try {
      mic.current = await startMicrophone({
        settings: stateRef.current.config?.vad_settings,
        onSpeechStart: handleSpeechStart,
        onSpeechEnd: handleSpeechEnd,
        onMisfire: handleMisfire,
      });
      setMicState("on");
    } catch {
      setMicState("denied");
    }
  }, [handleSpeechStart, handleSpeechEnd, handleMisfire]);

  const start = useCallback(async () => {
    await unlockAudio();
    const { session } = await api.post("/api/sessions", { clientMode });
    storeSession(session);
    dispatch({ type: "SESSION_STARTED", session });
    connect(session);
    startMic();
  }, [clientMode, connect, unlockAudio, startMic]);

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
        startMic();
      })
      .catch(() => clearStoredSession());
    return () => {
      cancelled = true;
    };
  }, [connect, startMic]);

  useEffect(() => () => disconnect(), [disconnect]);

  const speak = useCallback(
    async (text) => {
      const session = stateRef.current.session;
      if (!session) return;
      if (player.current.position() || stateRef.current.phase === "speaking")
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

  // Fetch and decode clips as soon as they are announced so the next one starts without a gap.
  useEffect(() => {
    state.queue.forEach((turn) => player.current.prefetch(turn, authHeaders()));
  }, [state.queue, authHeaders]);

  // Ordered playback: the next turn starts when its clip is decoded and the previous one has ended.
  // Callbacks are not tied to this effect's lifetime: interrupting stops the source, which silences onEnded.
  useEffect(() => {
    const turn = playableTurn(state);
    if (!turn || !["processing", "speaking"].includes(state.phase)) return;
    if (audioBlocked || player.current.position()) return;
    dispatch({ type: "PLAYBACK_STARTED", turnId: turn.id });
    player.current
      .play(turn, authHeaders(), (durationMs) => {
        send("playback.completed", { turnId: turn.id, spokenMs: durationMs });
        dispatch({ type: "PLAYBACK_FINISHED", turnId: turn.id });
        setPositionMs(0);
      })
      .then((durationMs) => {
        setAudioBlocked(false);
        send("playback.started", { turnId: turn.id, durationMs });
      })
      .catch((error) => {
        if (error.message === "audio-blocked") {
          setAudioBlocked(true);
          dispatch({ type: "PLAYBACK_ABORTED", turnId: turn.id });
        } else {
          send("playback.completed", { turnId: turn.id, spokenMs: 0 });
          dispatch({ type: "PLAYBACK_FINISHED", turnId: turn.id });
        }
      });
  }, [state, audioBlocked, send, authHeaders]);

  // Caption position for the live transcript, and coarse progress reports for the server.
  useEffect(() => {
    if (!state.current) return undefined;
    const caption = setInterval(
      () => setPositionMs(player.current.position()?.positionMs ?? 0),
      CAPTION_MS
    );
    const progress = setInterval(() => {
      const position = player.current.position();
      if (position)
        send("playback.progress", {
          turnId: position.turnId,
          positionMs: position.positionMs,
        });
    }, PROGRESS_MS);
    return () => {
      clearInterval(caption);
      clearInterval(progress);
    };
  }, [state.current, send]);

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
    if (state.phase !== "finalized") return;
    clearStoredSession();
    stopMicrophone();
  }, [state.phase, stopMicrophone]);

  return {
    state,
    positionMs,
    audioBlocked,
    micState,
    userSpeaking,
    unlockAudio,
    startMic,
    start,
    speak,
    interrupt,
    retry,
    leave,
  };
}
