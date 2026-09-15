# The Council

One visitor talks, by voice, with three AI characters: Aphra, Rosa and Claudia.
The experience is audio-first, always listening once started, interruptible at
any moment, and runs both in a browser and as a museum kiosk.

Architecture, data model and realtime protocol: [`docs/PLAN.md`](docs/PLAN.md).
Microphone tuning on site: [`docs/CALIBRATION.md`](docs/CALIBRATION.md).

## Stack

- **Rails 8** (Ruby 3.3), **PostgreSQL**, **Solid Queue / Cache / Cable** (no Redis)
- **React 19**, **Vite 5**, **Tailwind CSS 4**, **Heroicons**, **React Router**
- **Devise** as a JSON API for the admin; visitors never sign in
- **OpenAI** (Responses API for dialogue, transcription for speech-to-text) and
  **ElevenLabs** (text-to-speech), behind `Providers::*` adapters with `Fake` twins
- **Silero VAD** in the browser (`@ricky0123/vad-web`), **Web Audio** playback
- **RSpec**, **Vitest**, **Playwright**; deployed on **Fly.io**

## Getting started

```bash
bundle install && yarn install
cp .env.example .env      # names only in the example; fill in your keys
bin/rails db:prepare
bin/rails db:seed         # live configuration, three characters, admin account
bin/dev                   # Rails, esbuild, Tailwind, Vite HMR, Solid Queue worker
```

The app is served at http://localhost:3000. Pick the `fake` LLM, STT and TTS
providers in the admin to run the whole loop without any key.

## Environment variables

See `.env.example`. Secrets are environment variables only, never stored in the
database or editable from the admin.

| Variable | Purpose |
| --- | --- |
| `OPENAI_API_KEY` | Dialogue, speech-to-text and the live transcript preview |
| `ELEVENLABS_API_KEY` | Text-to-speech and the voice list in the admin |
| `LLM_MODEL` | Dialogue model copied into the live configuration on first seed |
| `LLM_TIMEOUT_MS` / `STT_TIMEOUT_MS` / `TTS_TIMEOUT_MS` | Per-request provider timeouts |
| `GENERATION_THREADS` / `TTS_THREADS` | In-process pools for dialogue generation (4) and speech synthesis (6) |
| `APP_URL` / `ACTION_CABLE_ALLOWED_ORIGINS` | Public URL for mail links and WebSocket origin checks |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Admin account created by `bin/rails db:seed` |
| `ALLOW_SIGNUP` | `true` exposes signup in production (off by default) |
| `PASSWORD` | Optional site-wide password gate for staging; blank disables it |
| `MAILER_SENDER` | From address for Devise mail |
| `AWS_*` / `BUCKET_NAME` | S3-compatible storage for avatars in production |
| `DB_POOL` | Active Record pool, defaults to `RAILS_MAX_THREADS` |

## How a conversation works

- `POST /api/sessions` creates a session and returns its token once. The browser
  keeps `{id, token}` in `localStorage` and can resume within the configured
  window; `FinalizeStaleSessionsJob` closes abandoned sessions every minute.
- The microphone stays on. Silero VAD detects utterances, encodes them as
  16 kHz WAV and posts them to `POST /api/sessions/:id/utterances`, where the
  STT provider transcribes them. The first detected language is pinned on the
  session. A typed input does the same job and is the accessibility path.
- While the visitor talks, an italic **You** line previews their words: the
  browser streams speech to the OpenAI Realtime transcription API with a
  short-lived key from `POST /api/sessions/:id/transcription_preview`. The
  uploaded utterance stays the transcript of record. `stt_settings` accepts
  `"live_preview": false`, `"preview_model"` and `"preview_url"`.
- Each visitor line starts one generation on the in-process pool, pinned to the
  session `version`; interruptions, retries and resets move the version so late
  results are dropped. `Conversation::PromptBuilder` assembles the editorial
  prompt, structural rules (four-way conversation, not everyone speaks, a
  `## Sounding human` section against machine-writing tells), character sheets
  and the script-style transcript. `ScriptParser` validates speakers, turn
  counts and stage cues, rewrites dashes into spoken punctuation, and sends
  rejected scripts back to the model with the error.
- `next_action` paces the group: `wait_for_user` (a question to the visitor),
  `yield_to_user` (natural pause, resumes after `yield_grace_ms`) and
  `continue` (a line aimed at another character, resumes after
  `continue_grace_ms`). Both grace periods are cancelled by any speech or
  typing, and the server refuses to chain more than `max_unprompted_segments`
  passages without a new visitor line. `turn_gap_ms` separates two lines.
- Turns are synthesized concurrently by the TTS provider as soon as the script
  is valid and announced one by one, so playback starts with the first clip.
  Clips live in `audio_clips` for the session only and are purged afterwards.
  Word timings drive live captions and keep only the heard words when the
  visitor interrupts. Stage cues such as `[laughs]` are voiced, never shown.
- Speech during playback pauses the loudspeaker at once and becomes an
  interruption after `interrupt_min_speech_ms`. The browser owns playback
  timing and reports it; only heard text reaches `conversation_events`.
- Resilience: bounded retries per provider call, every failure recorded in
  `provider_errors`, an `errored` state with **Try again**, reconnection with
  transcript reconciliation by `seq`, and a kiosk idle reset.
- URL flags: `?kiosk=true` (no footer, inactivity reset, larger transcript),
  `?textOnly=true` (audio-free mode at reading pace), `?simulateAudio=true`
  (timer-driven player for machines without sound output and for tests),
  `?lang=fr` (forces the UI locale).

## Admin

`/admin` is served by the React app over `/api/admin/*`. Any signed-in Devise
user is an admin.

- **Settings**: the single live configuration (prompt, providers and models,
  reasoning level, turn limit, timings, retry policy, VAD sliders). Changes
  apply to new conversations.
- **Characters**: name, personality sheet, avatar, voice and colour of the three
  agents. Voices come from the TTS provider, cached for 10 minutes.
- **Sessions**: the fifty most recent conversations with transcript, latency,
  metrics and provider errors; copy the transcript as a script or delete it.
- **Voice detection, live**: when an admin is signed in, the public page shows
  a **Voice detection** button (footer, or floating in kiosk mode). Its panel
  applies the VAD sliders to the running microphone at once, shows the live
  speech probability against both thresholds, and saves the values as the
  default. See `docs/CALIBRATION.md`.

## Testing

```bash
bundle exec rspec          # models, services, requests, channel, jobs
yarn test                  # Vitest: state machine, captions, VAD mapping, live preview
yarn e2e                   # Playwright against the fake providers
bin/rubocop && bin/brakeman && yarn lint
```

`yarn e2e` boots the app in the test environment on its own database
(`TEST_DATABASE=the_council_e2e`, seeded by `bin/rails e2e:seed` with the fake
providers and an `admin@example.com` account) and drives Chromium with a fake
microphone through start, ordered playback, interruption, resume, kiosk idle
reset, network loss and the admin tuning panel. Build the test assets first
with `bin/vite build --mode=test`. CI runs Brakeman, RuboCop, ESLint + Vitest +
build, RSpec and Playwright on every pull request.

## Deployment (Fly.io)

`fly.toml` defines two process groups from the `Dockerfile`: `app` (Puma behind
Thruster) and `worker` (`bin/jobs`). Migrations run as the release command.

```bash
fly launch --no-deploy --copy-config
fly secrets set RAILS_MASTER_KEY=… OPENAI_API_KEY=… ELEVENLABS_API_KEY=… \
  AWS_ACCESS_KEY_ID=… AWS_SECRET_ACCESS_KEY=… AWS_BUCKET=… APP_URL=https://<app>.fly.dev
fly deploy
fly ssh console -C "bin/rails db:seed"
```

Keep a single `app` machine running during an exhibition: in-flight generation
lives in the Puma process, and a restart makes the browser ask for that segment
again. Several Puma processes or machines still work together, since Action
Cable runs on Solid Cable and every commit checks the session `version` under a
row lock. Size `DB_POOL` above `RAILS_MAX_THREADS + GENERATION_THREADS +
TTS_THREADS` when the pools are busy.
