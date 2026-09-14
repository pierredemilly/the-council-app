# The Council

A web application where one visitor talks, by voice, with three AI-controlled
characters: Aphra, Rosa and Claudia. The experience is audio-first, always
listening once started, and the visitor can interrupt a character at any time.
The same app runs in a normal browser and as a museum kiosk.

The build plan and architecture live in [`docs/PLAN.md`](docs/PLAN.md).

## Stack

- **Rails 8** (Ruby 3.3), **PostgreSQL**
- **React 19** + **Vite 5** (HMR) + **Tailwind CSS 4.3** + **Heroicons** + **React Router**
- **Action Cable** on **Solid Cable** for realtime session events (no Redis)
- **Solid Queue** on Postgres for background jobs (finalization, metrics, cleanup)
- **Devise** for the admin sign-in, with React login / password views (JSON endpoints)
- **Active Storage** on **S3-compatible storage** for character avatars (local disk in development)
- **Alba** for JSON serialization
- **OpenAI** (Responses API for dialogue, transcription for speech-to-text) and **ElevenLabs** (text-to-speech), behind replaceable provider adapters
- **RSpec** for Rails tests, **letter_opener** for dev mail, **annotaterb**, **pry-rails**, **dotenv-rails**

## Getting started

```bash
bundle install
yarn install

cp .env.example .env      # then fill in the values

bin/rails db:prepare      # create + migrate

bin/dev                   # or: yarn dev
```

`bin/dev` runs everything in `Procfile.dev` (Rails server, esbuild/Tailwind
watchers, the Vite dev server, and a Solid Queue worker). The app is served at
http://localhost:3000.

## Environment variables

Configured via `dotenv-rails` in development and test; see `.env.example`.
Secrets are never stored in the database or editable from the admin.

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Dialogue generation (Responses API) and speech-to-text |
| `ELEVENLABS_API_KEY` | Text-to-speech and the voice list shown in the admin |
| `LLM_MODEL` | Default dialogue model, seeded into the live configuration (`gpt-5.6-luna`) |
| `LLM_TIMEOUT_MS` / `STT_TIMEOUT_MS` / `TTS_TIMEOUT_MS` | Per-request provider timeouts |
| `GENERATION_THREADS` | Size of the in-process pool running dialogue generation (default 4) |
| `TTS_THREADS` | Concurrent speech syntheses per Puma process (default 6) |
| `APP_URL` | Public URL of the deployment, used for mail links and Action Cable origin checks |
| `ACTION_CABLE_ALLOWED_ORIGINS` | Comma-separated extra origins allowed to open the WebSocket (production) |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Initial admin account created by `bin/rails db:seed` |
| `ALLOW_SIGNUP` | Set to `true` to expose account signup in production (off by default) |
| `PASSWORD` | Site-wide password gate for staging and previews. Unset/blank disables it (the default). |
| `MAILER_SENDER` | Default "from" address for Devise mail |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_REGION` / `AWS_BUCKET` | Active Storage S3 (production) |
| `AWS_ENDPOINT_URL_S3` / `BUCKET_NAME` | Non-AWS S3 providers (Tigris, R2, MinIO, …) |
| `DB_POOL` | Active Record pool size. Defaults to `RAILS_MAX_THREADS`. |
| `SECRET_KEY_BASE` / `RAILS_MASTER_KEY` | Standard Rails secrets, set on the production host only |

## Authentication

The admin UI is protected by Devise, set up as a JSON API consumed by React:

- Endpoints live under `/users/*` via custom controllers in `app/controllers/users/`.
- React screens are in `app/frontend/pages/` (`Login`, `Signup`, `ForgotPassword`, `ResetPassword`).
- `GET /current_user` returns the signed-in user; `app/frontend/lib/auth.js` exposes `useAuth()`.
- Visitors of the conversation itself are anonymous; they never sign in.

## Conversation engine

The public page (`/`) talks to Rails over one `ConversationChannel`
subscription per session plus a few JSON endpoints. Everything is described in
`docs/PLAN.md`; the short version:

- `POST /api/sessions` creates a session and returns its `token` once. The
  browser keeps `{id, token}` in `localStorage` and can resume for the
  configured window (10 minutes by default); `FinalizeStaleSessionsJob` runs
  every minute and finalizes abandoned sessions.
- `POST /api/sessions/:id/utterances` commits what the visitor said (typed text
  for now; audio arrives with the microphone slice) and starts a generation.
- Generation runs in-process on a bounded thread pool (`GENERATION_THREADS`,
  default 4), pinned to the session `version`. Interruptions, retries and
  resets move the version, so late results are discarded instead of spoken.
- `next_action` has three values: `wait_for_user` (a question to the visitor),
  `yield_to_user` (a natural pause, the group resumes after the grace period)
  and `continue` (the last line is aimed at another character). Both `yield`
  and `continue` are paced by the browser: `yield_grace_ms` and
  `continue_grace_ms` of silence pass before it asks for the next segment, so
  the visitor can step in, and the server stops chaining after
  `max_unprompted_segments` passages without a new visitor line. The parser
  also turns a closing question that names another character into `continue`.
  A configurable pause (`turn_gap_ms`) separates two consecutive lines.
- The browser owns playback timing: it reports `playback.started`,
  `playback.completed` and, on interruption, `speech.started` with the
  position reached. Only heard text is committed to the transcript.
- Dialogue comes from one shared call to the OpenAI Responses API
  (`Providers::Llm::OpenaiResponses`, official `openai` gem, strict JSON
  schema output, `reasoning.effort` from the admin setting). The prompt is
  assembled by `Conversation::PromptBuilder` (editorial prompt, structural
  rules, personality sheets, script-style transcript with interruption
  metadata); `Conversation::ScriptParser` rejects unknown speakers, visitor
  lines, malformed lines, too many turns, more than two turns per character
  and stage directions the TTS provider cannot voice. Rejected scripts are
  sent back to the model with the error, up to the configured retry count.
- Each turn is voiced by ElevenLabs (`Providers::Tts::ElevenLabs`, the
  `with-timestamps` endpoint, `eleven_v3` by default) as soon as the script is
  validated; the turns of one segment are synthesized concurrently
  (`TTS_THREADS`) and announced individually, so playback starts with the first
  clip while the others finish. Clips live in `audio_clips` for the session only
  (deleted on finalize, purged after an hour) and are served from
  `/api/sessions/:id/clips/:clip_id`; character alignment becomes word timings
  used for live captions and for keeping only the heard words on interruption.
- The browser plays clips through Web Audio (`lib/playback.js`) strictly in
  script order. `?simulateAudio=true` swaps in a timer-driven player for
  machines without an output device and for browser tests.
- The microphone is always on once a conversation starts. Silero VAD runs in
  the browser (`@ricky0123/vad-web`; model, worklet and wasm are copied to
  `public/vad/` by `vite.config.mts`) with echo cancellation, using the admin's
  VAD thresholds. Complete utterances are encoded as 16 kHz WAV and uploaded to
  `POST /api/sessions/:id/utterances`, transcribed by OpenAI
  (`Providers::Stt::Openai`, `gpt-4o-transcribe` by default) and committed as
  the visitor's line; the first detected language is pinned on the session and
  drives the prompt and later transcriptions. Speech during playback pauses the
  loudspeaker immediately and becomes an interruption after
  `interrupt_min_speech_ms`. See `docs/CALIBRATION.md` for tuning on site.
- Resilience: every provider call retries with the admin's bounded backoff,
  each failed attempt is recorded in `provider_errors` (stage, provider,
  attempt, sanitized message); a final failure puts the session in `errored`
  with a **Try again** button and the transcript intact. A lost connection
  pauses the loudspeaker, lets Action Cable reconnect for a minute, then offers
  **Retry connection**; on reconnection the server's `session.ready` reconciles
  events by `seq`. In kiosk mode a finished conversation returns to the idle
  screen by itself. Finalized sessions get counts, latency percentiles
  (STT, LLM, first clip, first audible word) and error tallies through
  `AggregateSessionMetricsJob`.
- Accessibility: the transcript doubles as live captions (words brighten as
  they are spoken) and, with **Text only** in the footer (`?textOnly=true`), as
  an audio-free mode where lines are shown at reading pace while the microphone
  and typed input keep working. Stage cues such as `[laughs]` are never
  displayed. Kiosk mode uses a larger transcript.
- While the visitor talks, an italic **You** line shows their words as they
  are recognised. With the OpenAI provider the browser streams the microphone to
  the Realtime transcription API with a short-lived key minted by
  `POST /api/sessions/:id/transcription_preview` (the main key never leaves the
  server); the transcript of record still comes from the uploaded utterance.
  `stt_settings` may carry `"live_preview": false` to switch the caption off,
  `"preview_model"` to pick another streaming model (default: the STT model
  when it is a `gpt-*` one, else `gpt-4o-mini-transcribe`) and `"preview_url"`
  to override the WebSocket endpoint.
- Select the `fake` LLM, TTS and STT providers in the admin to exercise the
  whole loop without keys: the fake TTS returns silent clips with synthetic word
  timings and the fake STT returns `stt_settings.fake_text`. The public page has a typed-input mode that doubles
  as the accessibility path.
- `?kiosk=true` (or the discreet "Kiosk mode" button) enables museum behaviour:
  no footer links and an inactivity reset.

## Admin

`/admin` (Settings and Characters) is served by the React app and backed by
`/api/admin/*`. Any signed-in Devise user is an admin; there are no other user
roles. Create the first account with `bin/rails db:seed` after setting
`ADMIN_EMAIL` / `ADMIN_PASSWORD`, or sign up in development. Signup is refused
in production unless `ALLOW_SIGNUP=true`.

- **Settings** edits the single live configuration (`AppConfig.current`):
  global system prompt, LLM / STT / TTS provider and model, reasoning level,
  turn limit, timings, retry policy, VAD thresholds and the operating-mode
  metadata. Changes apply to new conversations only.
- **Characters** edits the three agents (name, personality sheet, avatar,
  voice, colour). Voices come from the configured TTS provider through
  `GET /api/admin/voices`, cached for 10 minutes. Set the TTS provider to
  `fake` to explore without an ElevenLabs key. The colour is used for the
  name in the transcript and the avatar glow.
- **Sessions** lists the fifty most recent conversations; each one shows the
  transcript (with per-turn latency), aggregated metrics and provider errors,
  can be copied as plain script text, or deleted with everything attached.
- Voice activity detection is edited with sliders bounded by
  `AppConfig::VAD_RANGES`; the values are still stored as JSON in
  `vad_settings`, and the API rejects values outside the ranges.

## Site password gate

`SitePasswordProtection` (included in `ApplicationController`) puts a single
shared password in front of the whole app — useful for staging and client
previews, and unrelated to Devise sign-in.

- Set `PASSWORD` to switch it on; leave it unset or blank and the gate is a
  no-op, which is the default.
- HTML requests are redirected to `/unlock`; JSON requests get `401`.
- The unlocked state is a digest of the password stored in the Rails session,
  so rotating `PASSWORD` relocks everyone. Attempts are rate-limited.

## Background jobs

Active Job runs on Solid Queue, backed by the primary Postgres database.
Worker concurrency is configured in `config/queue.yml` and scheduled jobs in
`config/recurring.yml`. Nothing on the realtime conversation path (speech
recognition, dialogue generation, speech synthesis) goes through Active Job.

```bash
bin/jobs                  # run workers (bin/dev already does this)
```

## Deployment (Fly.io)

`fly.toml` defines two process groups built from the `Dockerfile`: `app`
(Puma behind Thruster) and `worker` (`bin/jobs`). Migrations run as the
release command.

```bash
fly launch --no-deploy --copy-config      # first time: creates the app, attach a Postgres cluster
fly secrets set RAILS_MASTER_KEY=… OPENAI_API_KEY=… ELEVENLABS_API_KEY=… \
  AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… AWS_BUCKET=… APP_URL=https://<app>.fly.dev
fly deploy
fly ssh console -C "bin/rails db:seed"    # creates the admin from ADMIN_EMAIL / ADMIN_PASSWORD
```

Keep a single `app` machine running during an exhibition: in-flight dialogue
generation lives in the Puma process, and a restart makes the client ask for
that segment again.

## Testing

```bash
bundle exec rspec          # Rails: models, services, requests, channel, jobs
yarn test                  # Vitest: client state machine, captions, VAD mapping
yarn e2e                   # Playwright: real browser against the fake providers
```

`yarn e2e` boots the app in the test environment on its own database
(`TEST_DATABASE=the_council_e2e`; `bin/rails e2e:seed` points the live
configuration at the fake providers, then `bin/rails server -e test`)
and drives Chromium with a fake microphone through start, ordered playback,
interruption, resume, kiosk idle reset and network loss. Build the test
assets first with `bin/vite build --mode=test`. Traces are kept on failure in
`test-results/`.

## Load and multi-worker notes

The realtime path is bound by provider latency, not CPU: one Puma process with
`RAILS_MAX_THREADS` threads plus the `GENERATION_THREADS` and `TTS_THREADS`
pools handles a museum installation with a handful of concurrent sessions.
Sessions are isolated rows, so more Puma workers or machines scale
horizontally: Action Cable runs on Solid Cable (PostgreSQL), so browsers
subscribed on one process receive broadcasts from another, and every
generation checks the session `version` under a row lock before committing.
To rehearse that locally, run two servers against the same database
(`PORT=3000 bin/rails s` and `PORT=3001 bin/rails s`), open a conversation on
one and reload it on the other: the transcript is reconciled from
`session.ready`. Size `DB_POOL` above `RAILS_MAX_THREADS + GENERATION_THREADS +
TTS_THREADS` when the pools are busy.

## Common commands

```bash
bin/rubocop                    # Ruby linting
bin/brakeman                   # Ruby security scan
yarn lint                      # ESLint over app/frontend
yarn build:vite                # production Vite build
bundle exec annotaterb models  # refresh model schema annotations
```

## Continuous integration

`.github/workflows/ci.yml` runs on every pull request and push to `main`:

- **scan_ruby** — Brakeman security scan
- **lint** — RuboCop
- **frontend** — ESLint + `vite build`
- **test** — RSpec against a Postgres service, after a Vite build (request
  specs render the layout, which needs the asset manifest)

- **e2e** — Playwright browser tests against the test server with fake providers
