# Phase 1 — Real chat (MVP)

> Status: in progress. Environment: laptop (Laragon + PostgreSQL), no VPS yet.
> Context: [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md)

## Goal

A new user can **sign up from a phone**, **verify their email**, **chat with a free AI model**
chosen by the admin, watch the answer **stream in piece by piece**, and see **the same history on
every phone** signed in to that account, updated in realtime. The admin manages providers, models,
users and quotas from **Lumi Console**.

## Out of scope for Phase 1

Tools & agent, action approval, memory, Lumi Bridge, voice, fingerprint, Google sign-in, push
notifications, VPS deploy.

---

## 0. Repo preparation

- [x] GitHub repo `RadhitaRayy/LUMI` cloned to `C:\Work\lumi`; monorepo `app/`, `docs/`, `design/`.
- [x] Technical identity renamed: Dart package `lumi`, application ID / bundle ID
  `io.github.radhitarayy.lumi`. The old app (`dev.juru.juru`) was removed from the phone by hand
  because it was installed as a separate app.
- [x] The app still passed analyze and tests after the move.
- [x] Local PostgreSQL (Laragon 18.7): user `lumi`, databases `lumi` and `lumi_test`.
- [x] `core/` scaffold: Laravel 13.44 + the React (Inertia) starter kit, connected to PostgreSQL,
  first migrations run, `npm run build` passes, 42 starter tests pass.
- [x] Dev email: Mailpit (SMTP on 127.0.0.1:1025, inbox at http://127.0.0.1:8025).
- [x] Pest 5 installed; tests use PostgreSQL `lumi_test` (not SQLite).

## 1. Lumi Core (Laravel)

### Setup

- Built from **Laravel's official React starter kit** (Inertia + React + TypeScript + Tailwind +
  shadcn/ui), plus Sanctum (mobile API), Reverb (realtime) and Prism PHP. Versions checked at install time.
- PostgreSQL database. Every mobile endpoint is under `/api/v1`, answers JSON, and errors carry a
  stable `code`.

### Database

| Table | Key columns |
|---|---|
| `users` | `name`, `email`, `locale` (`id`/`en`), `email_verified_at`, `password`, `role` (`superadmin`/`user`), `is_blocked`, `daily_quota` (nullable → the default) |
| `personal_access_tokens` | Sanctum's; one token per device (`name` = device name), `last_used_at` |
| `auth_codes` | `user_id`, `purpose` (`verify_email`/`reset_password`), `code_hash`, `expires_at`, `attempts`, `used_at` |
| `conversations` | `id` (ULID), `user_id`, `title`, `last_message_at`, timestamps |
| `messages` | `id` (ULID), `conversation_id`, `role` (`user`/`assistant`), `content`, `status` (`complete`/`error`/`cancelled`), `provider`, `model`, `input_tokens`, `output_tokens`, timestamps |
| `llm_providers` | `name`, `driver` (`openrouter`/`openai_compatible`/...), `base_url`, `api_key` (`encrypted` cast), `is_enabled`, `last_tested_at`, `last_error` |
| `llm_models` | `provider_id`, `model_id`, `label`, `is_default`, `supports_tools`, `is_enabled` |
| `user_ai_keys` | `user_id` (unique), `driver` (`openrouter`/`openai_compatible`), `base_url`, `api_key` (`encrypted` cast), `key_last4`, `model_id`, `is_active`, `last_validated_at`, `last_error` |
| `llm_usages` | `user_id`, `conversation_id`, `key_source` (`platform`/`user`), `provider`, `model`, `input_tokens`, `output_tokens`, `latency_ms`, `status`, `error_code` |
| `app_settings` | `registration_open`, `require_email_verification`, `default_daily_quota`, `system_prompt` |

### API — accounts & sessions

| Method & path | What it does |
|---|---|
| `POST /auth/register` | `name`, `email`, `password`, `device_name`, `locale` (optional) → `{user, token, token_id}` and sends a verification code. `403 registration_closed` when sign-up is closed. |
| `POST /auth/login` | `email`, `password`, `device_name` → `{user, token, token_id}`. `403 account_blocked` for blocked users. |
| `POST /auth/email/verify` | `code` → marks the email verified. |
| `POST /auth/email/resend` | Sends the code again (rate limited, e.g. once a minute). |
| `POST /auth/password/forgot` | `email` → sends a reset code. Always the same answer, even for unknown emails. |
| `POST /auth/password/reset` | `email`, `code`, `password` → changes the password and **revokes every token** (every device is signed out). |
| `POST /auth/logout` | Revokes this device's token. |
| `GET /me` · `PATCH /me` | Profile (name, `locale`), verification status, quota left today. |
| `PUT /me/password` | Changes the password (needs the current one). |
| `GET /devices` | Active devices (name, last used, "this device" flag). |
| `DELETE /devices/{id}` | Signs another device out. |

### API — the user's own AI key (BYOK)

| Method & path | What it does |
|---|---|
| `GET /me/ai-key` | Status of the user's key: provider, model, active, `key_last4`, last validated. **Never** returns the key. |
| `PUT /me/ai-key` | Saves/replaces the key: `driver`, `base_url` (for NIM / OpenAI-compatible), `api_key`, `model_id`. The key is checked first with a small call to the provider; failure → `422 ai_key_invalid`. |
| `POST /me/ai-key/test` | Tests the saved key again. |
| `PATCH /me/ai-key` | Turns it on/off without deleting it. |
| `DELETE /me/ai-key` | Deletes the key; the user goes back to the platform key (with the quota). |

`GET /me` includes `ai_key_source` (`platform`/`user`) and the quota left (only relevant on the platform key).

Verification/reset codes: 6 digits, stored hashed, valid for 15 minutes, at most 5 attempts.

### API — conversations

| Method & path | What it does |
|---|---|
| `GET /conversations` | The user's conversations, newest first, paginated, `?q=` to search. |
| `POST /conversations` | Creates a conversation. |
| `GET /conversations/{id}` | Details + messages. |
| `PATCH /conversations/{id}` | Renames it. |
| `DELETE /conversations/{id}` | Deletes it. |
| `POST /conversations/{id}/messages` | Sends a message; answers with **SSE** (below). Needs a verified email (`403 email_unverified`) when required. |

Every endpoint except register/login/forgot/reset needs `Authorization: Bearer <token>`.
Someone else's conversation → `404`.

### Language

- Every API request may send `Accept-Language` (`id` or `en`); errors, validation messages and
  `message` texts come back in that language. Anything else falls back to `APP_LOCALE` (`id`).
- The user's `locale` (set at sign-up or with `PATCH /me`) decides the language of code emails.
- The app translates errors itself from `code`; the server's `message` is a fallback.

### SSE streaming (to the sending device)

```
event: message.start   data: {"message_id":"01J...","user_message_id":"01J...","model":"...","key_source":"platform"}
event: delta           data: {"text":"a piece of text"}
event: message.end     data: {"message_id":"01J...","input_tokens":123,"output_tokens":45}
event: error           data: {"code":"provider_error","message":"..."}
```

- The user's message is stored before calling the provider; the assistant message is stored when
  it finishes (or with `status=error`/`cancelled` if it fails or the client disconnects).
- The conversation title is filled automatically from the first message (cut short), with no extra AI call.

### Realtime across devices (Reverb)

- Private channel `private-user.{id}`, authorised with the Sanctum token at
  `POST /api/v1/broadcasting/auth` (`socket_id`, `channel_name`). Another user's channel → `403`.
- The app sends an `X-Socket-ID` header (the socket id of its Reverb connection) with every request,
  so the device that made a change doesn't get its own event echoed back.
- Events go through the queue, so `queue:work` must run (dev: `php artisan dev`).
- Broadcast events:

| Event | When | Payload |
|---|---|---|
| `conversation.created` | A new conversation | conversation summary |
| `conversation.updated` | Renamed / a new message finished | summary + `last_message_at` |
| `conversation.deleted` | A conversation was deleted | `id` |
| `message.created` | A user message stored / an assistant answer finished | the full message |
| `session.revoked` | A device signed out / password changed / password reset | `token_ids` → devices whose `token_id` is listed go back to the sign-in screen |

- Phase 1 doesn't broadcast token-by-token text to other devices; they get the full answer when it finishes.
- Limitation: the server doesn't force-close the WebSocket of a signed-out device. The app must
  close it when it receives `session.revoked`; its token no longer works for the API or for joining
  the channel again.

### LLM Gateway

- One interface in Core (`App\Llm\...`) picks the **key source** and then calls Prism. The rest of
  the code doesn't know which provider is used.
- Order: the user's active key → otherwise the platform's default provider & model from the
  database. If the user's key fails, a clear error (`user_key_error`) is returned — no silent
  fallback to the platform key.
- System prompt from `app_settings`; history limited to the last N messages so it fits the context.
- Provider errors (quota used up, wrong key, timeout, model unavailable) map to clear `code`s.

### Quota & rate limits

- Daily quota = the user's messages per day (Asia/Jakarta) **on the platform key**. Used up →
  `429 quota_exceeded`, with a hint that the user can add their own key. Messages on the user's own
  key don't count toward the quota (rate limits still apply).
- Rate limits on login, register, resending codes, forgotten password and sending messages.
- Blocked user → every request `403 account_blocked`.

### First superadmin

- An artisan command creates/promotes a superadmin (`php artisan lumi:make-superadmin email`).
  Superadmins can't be created through sign-up.

## 2. Lumi Console (Inertia + React, `/console`)

Only `role=superadmin` (Lumi's owner), signed in with Laravel's web session. Built with shadcn/ui
components; tables and charts are hand-built (server-side pagination and filters, CSS bar charts),
so TanStack Table and Recharts aren't used. Dark only, following Lumi's identity
(`design/brand/README.md`). Designed on the canvas, sources in `design/console/`. The Console UI
stays in Indonesian.

Access:
- Web sign-in only for a superadmin who isn't blocked. Regular users get the same answer as a wrong
  password. The `superadmin` middleware on every Console and account-settings route also signs out
  anyone who isn't a superadmin (including through passkeys).
- No sign-up, email password reset, email verification or account deletion on the web.
  The owner's account is created and recovered with `php artisan lumi:make-superadmin`.

| Page | Contents |
|---|---|
| Dashboard | Summary cards (users, answers today, tokens today, errors), a 14-day answers/tokens chart, the default model, recent errors |
| Users | List, search, filters (unverified, blocked, own key), detail panel: per-user quota, AI key info (never the key), active devices + sign out, block/unblock (blocking revokes every token and sends `session.revoked`). Superadmins can't be blocked |
| Provider & model | One page (a model always belongs to one provider): add a provider (key tested first), replace the key, test the connection (result stored), enable/disable, delete; per provider: add a model (tested first), make default, enable/disable, delete. The default model can't be disabled or deleted |
| Usage log | Filter by user/model/status/date, paginated; never conversation content |
| Settings | Sign-up open/closed, email verification required, default quota, system prompt |

## 3. Lumi App (Flutter)

- Lives in `app/`. Core's address via `--dart-define=API_BASE_URL=...` (default
  `http://127.0.0.1:8000` through `adb reverse`), Reverb via `REVERB_KEY` / `REVERB_PORT`.
- **Riverpod** for state; `ApiClient` + token in `flutter_secure_storage`; a small Pusher-protocol
  client for Reverb.
- **Screens** (designed first on the [Lumi App canvas](https://claude.ai/artifact/MF2pY7SmjHPheUaT2iZMTQ),
  sources in `design/app/`): animated splash, Sign in, Sign up, Email verification (6-digit code +
  resend), Forgotten password (email → code + new password), Chat, History, Settings, Language,
  My AI key, Active devices, Session ended / quota used up.
- **Sign in / Sign up** call Core; validation errors (`422`) show per field; dedicated messages for
  `registration_closed`, `account_blocked`, `email_unverified`.
- **Auth gate:** open the app → valid, verified token → Chat; not verified → Email verification;
  no token → Sign in. A `session.revoked` event → "Session ended" dialog, then Sign in.
- **Chat:** send a message, read SSE, streaming text, typing indicator, a stop button, clear error
  messages (quota used up, network, provider).
- **History:** list from the server, search, open old conversations, delete, new conversation.
  Updated in realtime from other devices; refreshed when the app comes back to the foreground.
- **My AI key** (Settings): pick a provider (OpenRouter / NVIDIA NIM / OpenAI-compatible), paste the
  API key, enter the model, test; shows on/off + the last 4 characters; delete the key.
  The chat screen shows the key source and, on the platform key, the quota left.
- **Multilingual:** Indonesian and English from the start (ARB files, easy to add languages).
  Follows the phone's language by default (English for languages Lumi doesn't speak yet); can be
  changed in Settings → Language without signing out. The choice is stored on the phone and sent to
  Core (`locale` on the user + the `Accept-Language` header), so code emails, error messages and
  validation messages from the server follow the same language.
- **Feels alive, not static:** an animated splash (Lumi the cat appears, the lantern lights up,
  then the `lumi` wordmark) before the sign-in screen; screen transitions, popups/bottom sheets that
  animate in, press feedback on buttons, incoming-message and typing animations. The cat is drawn in
  code so its lantern, paw and eyes move. Motion turns off when the phone asks for reduced motion.
- The "fingerprint" and "Google" buttons on the sign-in screen are hidden for now.
- `DemoAgent` and the Phase 0 Tools/Voice screens were removed (their designs stay in `design/project/`).

## 4. Free providers for testing

Added by the admin through the Console; **keys are never committed**.

| Order | Provider | How it connects |
|---|---|---|
| 1 | **OpenRouter** (models labelled `:free`) | Prism's built-in OpenRouter driver |
| 2 | **NVIDIA NIM** (build.nvidia.com) | OpenAI-compatible endpoint (custom base URL) |

Current default model: `nvidia/nemotron-3-ultra-550b-a55b:free` through OpenRouter. The `:free`
list changes often and free models are often rate limited by their hosts (Gemma 4 on 2026-11-26),
so when testing a key, a 429 still counts as a valid key.

To check during implementation: free usage limits, streaming and tool-calling support per model,
and data policies (free tiers may use data for training — don't send sensitive data while testing).

## 5. Testing

- **Core:** Pest feature tests for register/login/blocking/closed sign-up, email verification &
  password reset (wrong, expired, too many attempts), devices & token revocation, conversation
  ownership, quota, SSE with a fake provider, broadcast events (`Event::fake`) and languages — without
  calling a real AI.
- **Console:** feature tests for admin-only access and the main actions (block a user, save a
  provider, change settings); `npm run build` and the TypeScript type-check pass.
- **App:** widget tests with a fake `ApiClient` (sign-in, verification, errors, streaming chat,
  history, realtime events) — still to write.
- **Manual:** two devices (phone + browser/emulator) on the same account → chat on one, it shows on
  the other; sign one device out from the other.

## 6. Definition of Done

- [ ] A new user can sign up, receive a code, verify their email and sign in from a phone.
- [ ] Forgotten password with a code works and signs every device out.
- [ ] The token is stored securely; signing out revokes it; other devices can be signed out from the device list.
- [ ] Chat with the free model chosen in the Console, answers stream in piece by piece.
- [ ] The same history on two devices with the same account, updated in realtime.
- [ ] Users can't see anyone else's data (neither through the API nor the realtime channel).
- [ ] Daily quota, user blocking, the sign-up switch and required verification from the Console take effect at once.
- [ ] API keys are stored encrypted and never appear in API responses.
- [ ] Switching the default provider/model in the Console (OpenRouter ↔ NVIDIA NIM) needs no code change.
- [ ] Users can add their own key in the app; chat then uses it and doesn't use up the quota;
  the key never appears in API responses or in the Console.
- [ ] The app works in Indonesian and English, and server messages and emails follow the chosen language.
- [ ] Core, Console and App tests pass; `flutter analyze` is clean.

## Progress

| Date | Done |
|---|---|
| 2026-11-25 | Repo preparation (monorepo, GitHub), `core/` scaffold on PostgreSQL |
| 2026-11-26 | **Auth API**: register, login, logout, email verification & forgotten password (6-digit codes, 15 minutes, at most 5 attempts), `GET/PATCH /me`, password change, list & sign out devices, `superadmin`/`user` roles, user blocking, `app_settings` (sign-up, required verification, default quota, system prompt), rate limits, `{code, message}` errors, `lumi:make-superadmin` command. 32 API tests + 42 starter tests pass, PHPStan level 7 clean |
| 2026-11-26 | **LLM Gateway + SSE chat + user BYOK**: Prism (the OpenRouter driver is also used for NVIDIA NIM through a custom base URL, because Prism's `openai` driver uses the Responses API), key selection (active user key → platform key), conversations (CRUD + search), `POST /conversations/{id}/messages` SSE streaming, daily quota on the platform key, usage log, provider errors with clear codes, `/me/ai-key` (saved after testing, re-test, on/off, delete), `lumi:add-provider` command. 91 tests pass, PHPStan clean |
| 2026-11-26 | **Real OpenRouter test**: sign up → verify code → conversation → streaming chat over HTTP with `nvidia/nemotron-3-ultra-550b-a55b:free` (answer in ~4 s, conversation context remembered, tokens recorded). Fixes from this test: `lumi:add-provider` checks the key's shape (paste with right-click), a 429 while testing a key counts as a valid key (also in `/me/ai-key`), failed answers no longer use up quota and deleting a conversation can't reset it. 100 tests pass |
| 2026-11-26 | **Realtime (Reverb)**: private channel `private-user.{id}` authorised with the Sanctum token, events `conversation.created/updated/deleted`, `message.created` (question right away, answer when finished), `session.revoked` (`token_ids`); `token_id` in the register/login response; the sending device is skipped via `X-Socket-ID`. 111 tests pass. Real WebSocket test 13/13: two devices on one account + another account (refused on join, receives nothing), a chat with a real AI shows on the other device, a signed-out device receives `session.revoked` |
| 2026-11-26 | **Brand + Lumi Console**: the cat with a lantern + the geometric `lumi` wordmark (`design/brand/`); Console at `/console`, superadmin only (Dashboard, Users, Provider & model, Log, Settings), no web sign-up/reset/account deletion, `last_tested_at`/`last_error` on providers. 113 tests pass, PHPStan clean, type-check and lint pass. Checked in the browser (desktop and phone width) with a test account, including a real connection test to OpenRouter |
| 2026-11-26 | **App design**: 11 screens with motion on the Lumi App canvas (`design/app/`) |
| 2026-11-26 | **Languages in Core**: `users.locale`, `Accept-Language` middleware, English source strings with `lang/id.json`, Indonesian validation messages, code emails in the user's language. 120 tests pass, PHPStan clean |
| 2026-11-26 | **Lumi App on Core**: every Phase 1 screen in Flutter with Riverpod, SSE chat, Reverb client, English + Indonesian, animated splash and motion; cat launcher icon and a dark launch screen. `flutter analyze` clean; installed on the Galaxy A56 |

| 2026-11-27 | **Smoother app + dev email**: release build that still reaches the laptop over `adb reverse` (cleartext to localhost only); sign-in screens shrink their header and hide the footer while the keyboard is open, keep the button above the keyboard, and close the keyboard on a tap outside; lighter layout (no `IntrinsicHeight`), compositor fades, chat list and send button rebuild on their own. Mailpit for verification and reset emails. NVIDIA NIM provider added in the Console and its connection test passes (`nvidia/nemotron-3.5-super-vl-120b-a12b`) |

| 2026-11-27 | **Stuck answers + richer chat**: slow free models hit PHP's 30-second limit mid-answer and left the answer `streaming` forever (endless typing dots). Streams now get 180 s, stale answers are marked `interrupted`, and the dev server runs 4 workers. Lumi's answers sit in bubbles and render Markdown (headings, lists, tables that scroll sideways, code blocks with a copy button); a finished answer from another device replaces its placeholder. NVIDIA NIM now answers chats (`nvidia/nemotron-3.5-super-vl-120b-a12b` as default). 121 Core tests pass |

Not yet: app widget tests beyond Markdown; the two-device end-to-end test.

## 7. Work order

1. Repo preparation: git, monorepo, PostgreSQL, Mailpit.
2. Canvas design: new app screens (verification, forgotten password, devices) and Lumi Console.
3. Core: setup, migrations, auth API (register, login, verification, reset, devices) + tests.
4. Core: LLM Gateway + SSE chat endpoint + tests with a fake provider.
5. Core: Reverb + broadcast events + channel authorisation + tests.
6. Console: layout + admin sign-in, providers, models, users, settings, log.
7. Test with OpenRouter, then NVIDIA NIM.
8. App: Riverpod, ApiClient, auth gate, Sign in/Sign up/Verification/Forgotten password.
9. App: SSE chat, History, realtime, active devices.
10. End-to-end test with two devices, tidy up, update the docs.

## Decisions

- [x] Repo layout: **monorepo** (`app/` + `core/`).
- [x] Database: **PostgreSQL** (dev & production).
- [x] Email verification & forgotten password: **in Phase 1** (6-digit codes).
- [x] App state management: **Riverpod**.
- [x] Realtime sync across devices: **in Phase 1** (Reverb).
- [x] Test providers: **OpenRouter**, then **NVIDIA NIM**.
- [x] BYOK: **hybrid** (platform key + quota, and the user's own key in the app), in Phase 1.
- [x] The Console is **superadmin**-only (the owner); Phase 1 roles: `superadmin` + `user`.
- [x] App languages: **Indonesian + English** from Phase 1.
- [ ] Production SMTP service (decided in Phase 3).
