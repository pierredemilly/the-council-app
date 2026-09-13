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
  voice). Voices come from the configured TTS provider through
  `GET /api/admin/voices`, cached for 10 minutes. Set the TTS provider to
  `fake` to explore without an ElevenLabs key.

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
bundle exec rspec
```

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

Browser tests (Playwright) are added in a later slice of the plan.
