// Pure client-side state for one conversation. No DOM, no network: the hook feeds it
// server messages and local playback facts, and renders from the result.

export const PHASES = [
  "idle",
  "starting",
  "listening",
  "processing",
  "speaking",
  "errored",
  "finalized",
];

export const initialState = {
  phase: "idle",
  session: null,
  config: null,
  connection: "disconnected",
  events: [],
  queue: [],
  current: null,
  speaker: null,
  nextAction: null,
  error: null,
  finalizeReason: null,
  version: 0,
  lastSeq: 0,
  seenEventIds: [],
  generationId: null,
  nextPosition: 0,
  pendingInterrupt: false,
};

const SEEN_LIMIT = 200;

const phaseForStatus = (status) =>
  status === "created" ? "listening" : status;

const sortTurns = (turns) => [...turns].sort((a, b) => a.position - b.position);

function remember(state, eventId) {
  const seen = [...state.seenEventIds, eventId];
  return seen.length > SEEN_LIMIT ? seen.slice(seen.length - SEEN_LIMIT) : seen;
}

function applyServerMessage(state, message) {
  if (!message || message.protocolVersion !== 1) return state;
  if (message.eventId && state.seenEventIds.includes(message.eventId))
    return state;
  if (typeof message.version === "number" && message.version < state.version) {
    return { ...state, seenEventIds: remember(state, message.eventId) };
  }

  const base = {
    ...state,
    version: Math.max(state.version, message.version ?? 0),
    seenEventIds: remember(state, message.eventId),
    pendingInterrupt:
      state.pendingInterrupt &&
      message.type !== "agent.segment.cancel" &&
      message.type !== "state.changed" &&
      !((message.version ?? 0) > state.version),
  };
  const { payload = {} } = message;

  switch (message.type) {
    case "session.ready": {
      const events = payload.events ?? [];
      const pending = sortTurns(payload.pendingTurns ?? []);
      return {
        ...base,
        phase: phaseForStatus(payload.status),
        config: payload.config ?? base.config,
        events,
        lastSeq: events.length ? events[events.length - 1].seq : 0,
        queue: pending,
        current: null,
        generationId: pending[0]?.generationId ?? null,
        nextPosition: pending[0]?.position ?? 0,
        nextAction: payload.nextAction ?? null,
        error: null,
      };
    }
    case "state.changed": {
      const phase = phaseForStatus(payload.status);
      return {
        ...base,
        phase,
        speaker:
          base.current?.speaker ??
          (phase === "speaking" ? (payload.speaker ?? null) : null),
        nextAction:
          payload.nextAction ??
          (phase === "listening" ? base.nextAction : null),
        finalizeReason:
          phase === "finalized"
            ? (payload.reason ?? null)
            : base.finalizeReason,
        error: phase === "errored" ? base.error : null,
      };
    }
    case "transcript.committed": {
      const event = payload.event;
      if (!event || event.seq <= base.lastSeq) return base;
      return { ...base, events: [...base.events, event], lastSeq: event.seq };
    }
    case "agent.turn.ready": {
      // Announcements that crossed a local interruption on the wire belong to a cancelled segment.
      if (base.pendingInterrupt && message.version <= state.version)
        return base;
      if (
        base.queue.some((t) => t.id === payload.id) ||
        base.current?.id === payload.id
      )
        return base;
      const newGeneration = payload.generationId !== base.generationId;
      return {
        ...base,
        generationId: payload.generationId,
        nextPosition: newGeneration ? 0 : base.nextPosition,
        queue: sortTurns([...(newGeneration ? [] : base.queue), payload]),
      };
    }
    case "agent.segment.cancel":
      return {
        ...base,
        queue: [],
        current: null,
        speaker: null,
        generationId: null,
        nextPosition: 0,
      };
    case "error.recoverable":
    case "error.fatal":
      return {
        ...base,
        error: { ...payload, fatal: message.type === "error.fatal" },
      };
    default:
      return base;
  }
}

export function reducer(state, action) {
  switch (action.type) {
    case "SESSION_STARTED":
      return {
        ...initialState,
        phase: "starting",
        session: action.session,
        config: action.session.config ?? null,
        version: action.session.version ?? 0,
        lastSeq: action.session.lastSeq ?? 0,
      };
    case "CONNECTION":
      return { ...state, connection: action.status };
    case "SERVER_MESSAGE":
      return applyServerMessage(state, action.message);
    case "PLAYBACK_STARTED": {
      const current = state.queue.find((t) => t.id === action.turnId);
      if (!current) return state;
      return {
        ...state,
        current,
        speaker: current.speaker,
        nextPosition: current.position + 1,
        queue: state.queue.filter((t) => t.id !== action.turnId),
      };
    }
    case "PLAYBACK_FINISHED":
      return state.current?.id === action.turnId
        ? { ...state, current: null }
        : state;
    case "PLAYBACK_ABORTED": {
      if (state.current?.id !== action.turnId) return state;
      return {
        ...state,
        current: null,
        speaker: null,
        nextPosition: state.current.position,
        queue: sortTurns([state.current, ...state.queue]),
      };
    }
    case "LOCAL_INTERRUPT":
      return {
        ...state,
        queue: [],
        current: null,
        speaker: null,
        phase: "listening",
        nextAction: null,
        generationId: null,
        nextPosition: 0,
        pendingInterrupt: true,
      };
    case "CLEAR_ERROR":
      return { ...state, error: null };
    case "RESET":
      return initialState;
    default:
      return state;
  }
}

// The turn that may play now: the head of the queue, only when it is the next position of the generation.
export const playableTurn = (state) => {
  const head = state.queue[0];
  if (!head || state.current) return null;
  return head.position === state.nextPosition ? head : null;
};

export const isReconnecting = (state) =>
  state.session !== null &&
  state.phase !== "finalized" &&
  state.connection !== "connected";
