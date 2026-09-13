# The Council — V1 coding plan

Status: **validated 2026-09-13**. Source: the V1 build specification; decisions recorded in section 8.
Slices are delivered one PR at a time, each PR carrying a short testing and exploring guide.

## 0. Decisions already implied by the template

- Stay on the template's JavaScript convention (JSX in `.js`), not TypeScript.
- Solid Cable, Solid Queue and Solid Cache are already installed and migrated; production `cable.yml` already uses `solid_cable`. Nothing to add there.
- Rename `RailsReactVite` → `TheCouncil`, `rails_react_vite` → `the_council`, "Rails React Vite" → "The Council" in the first commit, and delete the template setup notes from `README.md` / `AGENTS.md`.
- New JSON endpoints live under `/api/...`; the SPA catch-all in `config/routes.rb` is extended to skip `/api` and `/cable`.
- Public visitors are anonymous (no Devise). A conversation session is authorised by a random `client_token` issued at creation and stored in `localStorage` with the session id. Every `/api/sessions/:id/*` request and the Action Cable subscription must present it.

## 1. Architecture at a glance

```
Browser (React)                              Rails (Puma, multi-thread)               Providers
─────────────────────────────                ──────────────────────────────────────    ─────────
mic ─► VAD (Silero, in-browser) ─► WAV ─► POST /api/sessions/:id/utterances ─► Stt ─► OpenAI STT
                                             │ commit human event (seq++, version++)
                                             │ spawn SegmentRunner thread (version v)
                                             │    Llm.generate_segment ─────────────► OpenAI Responses
                                             │    parse + validate envelope (retry w/ error)
                                             │    Tts.synthesize ×N concurrently ─────► ElevenLabs
                                             │    store clips (audio_clips, expires_at)
                                             │    if version still == v: broadcast agent.turn.ready
ConversationChannel ◄─── Action Cable (Solid Cable) ◄──┘
speaker ◄─ WebAudio playback ◄─ GET /api/sessions/:id/clips/:clip_id
   │ playback.progress / playback.completed / speech.started (interrupt) ──► channel ──► Orchestrator
```

Key invariants (from the spec, restated as code rules):

1. Only Rails writes `conversation_events`; every write bumps `sessions.version` inside one transaction with optimistic locking.
2. Every generation attempt carries the `version` it started from. Nothing is broadcast or committed if `sessions.version` moved on.
3. The transcript only ever contains what was heard: AI text is committed on `playback.completed`, or as a truncated prefix on interruption. Speculative turns live in `session_turns` (status `pending`) until then.
4. No audio at rest beyond the session: `audio_clips` rows are deleted on finalize and by a sweeper job; microphone audio is transcribed from memory and never written to disk.
5. Nothing on the realtime path goes through Active Job. Solid Queue only runs finalization, metrics aggregation and cleanup.

### 1.1 Why in-process threads for generation

The spec forbids putting STT/LLM/TTS behind Active Job, yet an LLM+TTS round trip is 3–10 s and must not block the utterance upload response. Proposal: `Conversation::SegmentRunner` runs on a bounded `Concurrent::ThreadPoolExecutor` inside the Puma process (wrapped in `Rails.application.executor.wrap`, own DB connection from the pool). The version check makes a runner that outlives an interruption or lands on another worker harmless. If Puma restarts mid-generation the client's heartbeat/timeout asks the server to regenerate (`turn.request`), so no state is lost. `RAILS_MAX_THREADS`/`DB_POOL` are sized for this (documented in README).

### 1.2 Who owns timers

The browser owns playback timing, so it also owns the two soft timers: the `yield_to_user` grace period and the museum inactivity timeout. It reports them as channel actions (`turn.request`, `session.idle_reset`) and the server validates them against its own state (status, `last_activity_at`) before acting. The hard timer (10 min without a connected page → finalize) is server-side, via a recurring Solid Queue job reading `last_seen_at`.

## 2. Data model

| Table | Purpose / notable columns |
| --- | --- |
| `app_configs` | singleton. `global_system_prompt`, `llm_provider`, `llm_model`, `reasoning_level`, `stt_provider`, `stt_model`, `stt_settings jsonb`, `tts_provider`, `tts_model`, `tts_settings jsonb`, `max_ai_turns` (6), `inactivity_reset_seconds` (300), `resume_window_seconds` (600), `yield_grace_ms`, `retry_count` (3), `retry_base_ms`, `retry_max_ms`, `vad_settings jsonb` (thresholds, min speech ms, debounce), `operating_mode` (`cloud_pi` / `local_gpu`), `conversation_language` |
| `agents` | exactly three rows, `position` 1..3, `name` (unique, no `:`), `personality` text (size-limited), `voice_id`, `voice_name`, `has_one_attached :avatar` |
| `conversation_sessions` | `id uuid`, `client_token_digest`, `status` (`created`, `listening`, `processing`, `speaking`, `reconnecting`, `finalized`, `errored`), `client_mode` (`browser`/`kiosk`), `config_snapshot jsonb` (config + agents at start), `version int`, `next_seq int`, `started_at`, `first_utterance_at`, `last_seen_at`, `last_activity_at`, `finalized_at`, `finalize_reason`, `metrics jsonb` (filled on finalize) |
| `conversation_events` | canonical transcript. `session_id`, `seq` (unique per session), `kind` (`human`, `agent`, `system`), `speaker` (agent name or null), `text`, `interrupted bool`, `spoken_ms`, `latency jsonb` (`stt_ms`, `llm_ms`, `first_clip_ms`, `first_audio_ms`), `occurred_at` |
| `session_turns` | speculative generated turns. `session_id`, `generation_id`, `version`, `position`, `speaker`, `text`, `stage_directions jsonb`, `status` (`pending`, `ready`, `playing`, `spoken`, `discarded`), `next_action` on the last turn |
| `audio_clips` | `id uuid`, `session_turn_id`, `mime`, `bytes bytea`, `duration_ms`, `timings jsonb` (word start/end ms), `expires_at`. Purged on finalize and hourly. |
| `provider_errors` | `session_id`, `stage` (`stt`/`llm`/`tts`/`parse`), `provider`, `attempt`, `recoverable`, `message` (sanitised, no transcript), `created_at` |

Named `conversation_sessions` rather than `sessions` to avoid clashing with Devise/Rails session vocabulary.

## 3. Service boundaries (Ruby)

```
app/services/
  conversation/
    session_store.rb        # load w/ lock, commit_event!(session, expected_version, attrs), bump_version!
    orchestrator.rb         # state machine: handle(action, payload) → transitions + side effects
    transcript.rb           # canonicalisation, prefix truncation from word timings
    segment_runner.rb       # LLM → parse → TTS fan-out → version check → broadcast
    prompt_builder.rb       # system prompt + sheets + transcript + interruption metadata
    script_parser.rb        # envelope → turns; all validation rules from spec §6
    retry_policy.rb         # bounded exponential backoff + jitter, from config
    broadcaster.rb          # the only place that calls ActionCable.server.broadcast
    protocol.rb             # message constants, PROTOCOL_VERSION, payload validation
  providers/
    llm/base.rb, llm/openai_responses.rb, llm/fake.rb
    stt/base.rb, stt/openai.rb,           stt/fake.rb
    tts/base.rb, tts/eleven_labs.rb,      tts/fake.rb
    registry.rb             # provider name → adapter, from config snapshot
app/channels/conversation_channel.rb   # transport only, delegates to Orchestrator
app/controllers/api/sessions_controller.rb, api/utterances_controller.rb, api/clips_controller.rb, api/config_controller.rb
app/controllers/admin/agents_controller.rb, admin/settings_controller.rb, admin/voices_controller.rb
app/jobs/finalize_stale_sessions_job.rb, purge_audio_clips_job.rb, aggregate_session_metrics_job.rb
```

Provider adapters return plain value objects (`LlmSegment`, `TranscriptResult`, `TtsResult{audio, mime, timings}`) and raise `Providers::Error{recoverable:}`; orchestration never sees HTTP.

## 4. Realtime protocol (v1)

Implementation notes (slice 3): protocol and session JSON use lowerCamelCase keys, the admin API stays snake_case. `version` is the generation epoch: it moves on human utterances, interruptions, `turn.request`, resets and finalization, never on ordinary commits; `seq` orders events. `speech.started` may carry `turnId`, `positionMs` and `durationMs` so the interruption is handled atomically in one message; `playback.stopped` is the explicit-stop variant of the same thing. `client.heartbeat` is answered with `server.heartbeat`.

Every message: `{ protocolVersion: 1, sessionId, eventId (uuid), ... }`. Server→client messages carry `seq` (last committed) and `version`; the client drops anything whose `version` is older than what it has seen.

Client → server (channel `perform`): `session.resume`, `speech.started`, `speech.ended`, `playback.started`, `playback.progress {turnId, positionMs}`, `playback.stopped {turnId, positionMs}`, `playback.completed {turnId}`, `turn.request` (grace period elapsed), `session.idle_reset`, `client.heartbeat`.
`session.start` and `utterance.uploaded` are HTTP (`POST /api/sessions`, `POST /api/sessions/:id/utterances`) so the audio never touches the socket.

Server → client: `session.ready {snapshot, events, pendingTurns}`, `state.changed {status}`, `transcript.committed {event}`, `agent.turn.ready {turn, clipUrl, durationMs, timings, nextAction}`, `agent.segment.cancel {generationId}`, `error.recoverable`, `error.fatal`, `server.heartbeat`.

Implementation notes (slice 4): adapters return a raw `Providers::Llm::Envelope`; `Conversation::SegmentGenerator` owns the parse-and-feedback loop (network retries via `RetryPolicy`, script rejections fed back as a second user message, both bounded by `retry_count`). Stage-direction allowlists live on the TTS adapters (`Providers::Tts::Base::STAGE_DIRECTIONS`) so the parser only accepts cues the active voice provider can render. Token usage and LLM latency are accumulated in `conversation_sessions.metrics` and stamped on the triggering human event's `latency.llm_ms`.

Implementation notes (slice 5): turns are persisted `pending`, then `Conversation::ClipSynthesizer` synthesizes them concurrently on a dedicated pool and flips each to `ready` (with its `audio_clips` row) under the version lock, broadcasting `agent.turn.ready` per turn with `clipUrl`, `durationMs` and word `timings`. The client plays strictly by `position` within a `generationId` and prefetches/decodes clips as they arrive. `playback.started` now carries the decoded `durationMs` so the server has a duration even without provider timings. Web Audio `resume()` is raced against a short timeout: when audio stays blocked the turn is re-queued and an "Enable sound" button appears; `?simulateAudio=true` selects a timer-driven player for tests and speakerless machines.

Implementation notes (slice 6): the VAD runtime assets are copied into `public/vad/` when Vite starts or builds, so they ship with the Docker image without a separate step. Speech during playback pauses the Web Audio context at once; the interruption message is sent only after `interrupt_min_speech_ms` of continuous speech (or at speech end), and a VAD misfire resumes playback. Uploads are validated (type allowlist, 5 MB cap) in `Conversation::Transcriber`, which also pins `conversation_sessions.language` from the first detected language. `gpt-4o-transcribe` reports languages through the `languages` array of the JSON response; `whisper-*` models use `verbose_json`. An empty transcription answers `no_speech` and the client sends `turn.request` if it had interrupted the characters.

Implementation notes (slice 7): every `speech.started` is acknowledged with `agent.segment.cancel` even when the server had nothing to cancel, and the client holds back `agent.turn.ready` messages carrying the pre-interruption version until that acknowledgement arrives, so a turn announced on the wire just before a local interruption can never be played. Clips are deleted as soon as their turn is spoken, not only on discard or finalize. `spec/services/conversation/interruption_races_spec.rb` covers interruptions during generation, during clip preparation, between clips, with stale turn ids, mid-turn with a follow-up utterance, and duplicate completion reports after a reconnect.

Implementation notes (slice 8): `RetryPolicy#run(on_error:)` reports every failed attempt; `SegmentGenerator`, `ClipSynthesizer` and `Transcriber` record them in `provider_errors` (stages `llm`, `parse`, `tts`, `stt`). `playback.started` for a segment's first turn stamps `first_audio_ms` on the triggering human event; `finalize!` enqueues `AggregateSessionMetricsJob`, which writes counts, per-key latency percentiles and error tallies into `metrics`. The client pauses the loudspeaker while disconnected, shows "Retry connection" after 60 s (forcing `connection.reopen()`), and in kiosk mode returns to the idle screen a few seconds after finalization.

Implementation notes (slice 9): Playwright lives in `e2e/` with `playwright.config.mjs` booting Rails in the test environment after `bin/rails e2e:seed` (fake providers, short inactivity and resume windows); tests use `?simulateAudio=true`, a fake media device and `page.clock` for the kiosk timer, and `context.setOffline` for network loss. `?textOnly=true` reuses the simulated player as the audio-free accessibility mode. Stage cues are removed from displayed captions together with their word timings (`lib/captions.js`).

Feedback round 1 (conversation behaviour): `next_action` gains `continue` for passages that end on a line aimed at another character; the server starts the next generation when that line is spoken, and the parser coerces a closing question naming another character to `continue`. The prompt rules now frame a four-way conversation and forbid ending on a question to a character with `wait_for_user`. A new human utterance that supersedes queued or in-flight turns broadcasts `agent.segment.cancel`, and the browser treats speech while the group is thinking as an interruption after the debounce. The avatar highlight follows the locally playing turn only. `turn_gap_ms` (default 700) adds a breath between consecutive lines.

Feedback round 1 (admin): VAD settings are sliders bounded by `AppConfig::VAD_RANGES` (validated server-side too, with negative ≤ positive), still stored as JSON. Agents carry a `color` (palette default by position) used for transcript names and avatar glow. `/admin/sessions` lists recent conversations and `/admin/sessions/:id` shows the transcript with latency, metrics and provider errors, copies it as script text, or deletes the session.

Feedback round 2 (pacing): `continue` no longer triggers generation server-side; the segment ends `listening` with `nextAction: continue` and the browser waits `continue_grace_ms` (default 2 s) before `turn.request`, as it waits `yield_grace_ms` (default now 5 s) after a yield. `request_turn!` refuses once `max_unprompted_segments` (default 2) passages have been spoken since the visitor's last line and reports `wait_for_user` instead, so the group cannot talk to itself indefinitely. The prompt tells the model that one or two lines are often enough.

Feedback round 3 (voice): the prompt rules end with a `## Sounding human` section listing the recognised tells of generated text (dashes, negative parallelism, rule of three, warm-ups and validation phrases, therapy speak, inflated vocabulary, hedging, closing morals), distilled from Wikipedia's *Signs of AI writing* guide and similar lists. As a safety net, `ScriptParser` rewrites em and en dashes into commas, ellipses or nothing before a turn is stored or voiced.

Feedback round 3 (live VAD tuning): a signed-in admin sees a **Voice detection** button on the public page. `VadTuner` reuses the admin sliders, shows the live speech probability from `onFrameProcessed`, applies changes to the running `MicVAD` through `setOptions` (an override kept in the hook, ahead of the session snapshot) and saves them through `PUT /api/admin/config`.

## 5. Frontend layout

```
app/frontend/
  pages/Conversation.js            # public UI (idle → listening → … ), avatars, transcript
  pages/admin/Settings.js, pages/admin/Agents.js, pages/admin/AgentForm.js
  components/RequireAuth.js, components/AvatarStage.js, components/TranscriptPanel.js, components/MicIndicator.js
  lib/cable.js                     # @rails/actioncable consumer + typed send/receive, reconnect w/ 60 s auto retry
  lib/session.js                   # localStorage {id, token}, resume rules
  lib/vad.js                       # @ricky0123/vad-web wrapper, thresholds from config, WAV encoding
  lib/playback.js                  # WebAudio queue: ordered clips, position reporting, hard stop
  lib/conversationMachine.js       # pure client state machine (testable without DOM)
  hooks/useConversation.js         # glues cable + vad + playback + machine
```

Dependencies to add: `@rails/actioncable`, `@ricky0123/vad-web` (+ `onnxruntime-web`, static wasm/onnx assets copied via Vite), `vitest` for pure-JS unit tests.

## 6. Vertical slices (each ends green on `bundle exec rspec`, `bin/rubocop`, `bin/brakeman`, `yarn lint`, `yarn build:vite`)

1. **Bootstrap** (done) — rename app, drop template notes, `.env.example` placeholders (`OPENAI_API_KEY`, `ELEVENLABS_API_KEY`, `APP_URL`, `ACTION_CABLE_ALLOWED_ORIGINS`, `SESSION_TOKEN_SECRET`, `LLM_TIMEOUT_MS`, `STT_TIMEOUT_MS`, `TTS_TIMEOUT_MS`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `ALLOW_SIGNUP`), `openai` + `concurrent-ruby` gems, cable allowed origins from env, README skeleton.
2. **Schema + admin** (done) — migrations for the configuration tables (`app_configs`, `agents`, Active Storage; session tables land with slice 3), models + validations, seeds (3 placeholder agents, default config, admin from env), `rails admin:create`, signup disabled in production unless `ALLOW_SIGNUP`, Alba serializers, `/api/admin/*` endpoints, React admin pages (settings form, agent form with avatar upload and voice select), ElevenLabs voice list endpoint with Solid Cache.
3. **Session core + protocol with fakes** (done) — `ConversationSession` lifecycle, `SessionStore`, `Orchestrator`, `ConversationChannel`, `POST /api/sessions`, resume, heartbeats, `Providers::*::Fake`, public `Conversation` page in text mode (type a line instead of speaking) so the whole loop is exercisable without audio. Recurring `FinalizeStaleSessionsJob`.
4. **LLM engine** (done) — `PromptBuilder`, `ScriptParser` (all rejection rules), retry-with-validation-error, `OpenaiResponses` adapter with strict JSON schema output and configurable reasoning, token/latency recording, `SegmentRunner` skeleton (text only).
5. **TTS + playback** (done) — `ElevenLabs` adapter (`with-timestamps`, character → word timings), concurrent synthesis, `audio_clips` + clip endpoint, WebAudio ordered playback, first-clip-ready start, speaker highlight, purge job.
6. **Mic + VAD + STT** (done) — `getUserMedia` with echo cancellation, Silero VAD, WAV upload, OpenAI STT adapter, first-utterance-starts-discussion, mic indicator, adjustable thresholds surfaced from config.
7. **Interruption** (done) — `speech.started` during playback: hard stop, cancel queued clips, `Transcript.truncate_to(position_ms, timings)`, commit `interrupted: true`, discard pending turns, regenerate with interruption metadata; ellipsis rendering; empty-STT fallback (regenerate, don't replay).
8. **Resilience + museum** (done) — retry policy in every adapter, processing state during retries, final-failure UI with explicit retry, reconnect (auto 60 s then `Retry connection`), reconciliation by `seq`, kiosk mode (`?kiosk`) inactivity reset, metrics aggregation on finalize, `provider_errors`.
9. **Polish + tests** (done) — accessibility transcript mode, kiosk idle screen, Playwright browser tests with fake microphone, race tests, calibration doc (`docs/CALIBRATION.md`), deployment notes (`config/deploy.yml`, `Procfile.dev`, `recurring.yml`).

## 7. Testing strategy

- RSpec: model, service (parser, transcript truncation, retry policy, orchestrator transitions, stale-version rejection with two concurrent runners), request (API + admin auth), channel, job specs. Providers always faked; adapters get unit specs with recorded/stubbed HTTP (WebMock).
- Vitest: `conversationMachine`, `playback` queue ordering, timing truncation helper, cable message de-duplication.
- Playwright (Chromium is preinstalled here): permission prompt, start → speak (fake audio file) → hear ordered clips, interruption, reconnect, resume within/after 10 min (clock mocked), kiosk idle reset. Runs against Rails with `Providers::*::Fake` selected via `PROVIDERS=fake`.
- Manual museum calibration checklist documented, not automated.

## 8. Decisions (validated with Pierre, 2026-09-13)

| Topic | Decision |
| --- | --- |
| Naming | `TheCouncil` / `the_council` / "The Council". Kamal removed entirely. |
| Hosting | Fly.io: `app` and `worker` process groups from the `Dockerfile`, Fly Postgres, migrations as release command. |
| LLM | OpenAI Responses API via the official `openai` gem. Model id `gpt-5.6-luna`; `reasoning.effort` from the admin setting (`none` or `low`). |
| STT | OpenAI transcription for V1; adapter interface kept for Deepgram / ElevenLabs Scribe. |
| TTS | ElevenLabs, `eleven_v3` by default (audio tags), model exposed as an admin setting. |
| Language | The UI is fully localized (fr/en now, more later, e.g. ja/ko). V1 conversations are single-language: the language of the visitor's first utterance (STT detection) is stored on the session and drives the prompt and STT hint. Per-character languages and subtitles are V2. |
| Kiosk mode | `?kiosk` query flag, plus a discreet bottom-right button on the normal page that enters kiosk mode. Inactivity reset applies only in kiosk mode. |
| Admin | Any signed-in Devise user is an admin; there are no other users. First admin seeded from `ADMIN_EMAIL` / `ADMIN_PASSWORD`; signup disabled in production unless `ALLOW_SIGNUP=true`. |
| Generation | In-process bounded thread pool inside Puma, version-tagged; Puma is not restarted during an exhibition. |
| VAD | Silero via `@ricky0123/vad-web` in the browser; thresholds come from the admin VAD settings. |
| Browser tests | Playwright, as a separate CI job. |
| Personas | Aphra, Rosa, Claudia. Sheets, avatars and voices supplied later; seeds ship neutral placeholders. |
| Delivery | One PR per slice against `main`, each with a testing and exploring guide. Provider keys live in Pierre's `.env`; development and CI use fake adapters. |
