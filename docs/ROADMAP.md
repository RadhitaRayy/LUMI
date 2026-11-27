# Lumi roadmap

> Drafted 2026-11-25. Phases 1 and 2 are built on the laptop (Laragon) while the VPS gets ready.
> Architecture and the reasons behind decisions: [ARCHITECTURE.md](ARCHITECTURE.md).

| Phase | Goal | Status |
|---|---|---|
| 0 | UI design + Flutter demo app | ✅ Done (2026-11-25) |
| [1](PHASE-1.md) | Real chat end to end: accounts + email verification, history synced in realtime across phones, hybrid BYOK (platform key + the user's own key), superadmin Console | ✅ Done (2026-11-27) |
| [2](PHASE-2.md) | Agent orchestrator, strict 4-layer system prompt, user persona, tools, approval, memory | ⏳ Spec ready |
| 3 | Deploy to the VPS + release APK | Planned |
| 4 | Lumi Bridge (laptop) + phone features (fingerprint, voice, push) | Planned |
| 5 | Autonomy & integrations (routines, Telegram, calendar, knowledge base) | Planned |

---

## Phase 0 — Design & demo ✅

- Seven screens designed (Sign in, Sign up, Chat, Action approval, Voice mode, Tools, History & memory).
- A Flutter app with mock data (`DemoAgent`), running on Android (Galaxy A56) and the web.
- `flutter analyze` clean, 6 tests passing.

## Phase 1 — Real chat (MVP)

Full spec: [PHASE-1.md](PHASE-1.md).

- **Repo:** monorepo (`app/` + `core/`), PostgreSQL, Mailpit for dev email.
- **Core:** open sign-up + email verification & forgotten password (6-digit codes), one session per
  device (Sanctum) + a list of active devices, conversations & messages, SSE chat streaming,
  realtime sync across devices (Reverb), daily quota + rate limits, an LLM Gateway (Prism) tested
  with OpenRouter and then NVIDIA NIM, hybrid BYOK (a platform key with a quota + the user's own key).
- **Console (Inertia + React + shadcn/ui, superadmin only):** providers & platform keys
  (encrypted), models, users (verification, blocking, quota, devices), settings, usage log.
- **App:** Riverpod; sign-in, sign-up, email code and password reset wired to Core; real chat
  replaces `DemoAgent`; history from the server, updated in realtime; active devices; My AI key;
  English and Indonesian.

**Done when:** a new user can sign up and verify their email from a phone, chat with a free model
chosen by the superadmin or with their own key, see the answer stream in piece by piece, see the
same history update in realtime on two phones signed in to the same account, and quota, blocking
and settings from the Console take effect.

## Phase 2 — Agent, tools and approval

- Tool calling in Core (through Prism) + a tool registry with `auto` / `ask` modes.
- Safe server-side tools: `notes` (save/search), `memory` (remember/forget), `time`, `web_search`
  (if a reasonable free API exists).
- Approval flow end to end: an `ask` action is sent to the app (Reverb, in place since Phase 1),
  the user approves or rejects, and the agent carries on. Every action goes to an **audit log**.
- Per-user memory: the Memory screen in the app is wired up and entries can be deleted.
- Console: manage tools & permissions per role, view the audit log.
- Tool cards in chat (`ToolCallCard`, `PendingActionCard`) use real data.

**Done when:** the agent picks tools by itself, `ask` actions wait for approval from the phone,
and saved memories are used in later conversations.

## Phase 3 — Deploy to the VPS

- Ubuntu VPS + Docker Compose (Core, PostgreSQL, queue worker, Reverb) + Caddy (HTTPS) + a domain.
- A production SMTP email service for verification and reset codes.
- Scheduled database backups, logs, basic monitoring (uptime).
- Production config: separate env, `APP_DEBUG=false`, rate limits, CORS.
- App: a release APK pointing at the VPS domain (the `INTERNET` permission is already in the main
  manifest).
- iOS: a PWA (Add to Home Screen) or an IPA built on macOS CI + sideloading.

**Done when:** the app on the phone uses Core on the VPS over HTTPS without the laptop running.

## Phase 4 — Lumi Bridge & phone features

- **Bridge** (Node.js): a daemon on the laptop/bot server with an outbound WebSocket to Core,
  a token per bridge, and admin-only tools:
  `check_bot_status`, `read_log`, `restart_bot` (approval), `run_script` (allowlist, approval),
  `git_pull` (approval). Online/offline status shows in the app and the Console.
- **Phone:** unlock with fingerprint/Face ID (`local_auth`), voice input in Indonesian and English
  (`speech_to_text`), push notifications (FCM), an offline view.

**Done when:** from the phone, the admin can see the status of the bots on the laptop and restart
them with approval, and approval notifications arrive even when the app is closed.

## Phase 5 — Autonomy & integrations

- Scheduled routines (Scheduler), e.g. "check the bots every morning, tell me if there's an error".
- Proactive notifications with quiet hours, de-duplication and send limits.
- A Telegram channel (chat with Lumi through a Telegram bot).
- Connectors: Google Calendar (read first), then others.
- A personal knowledge base (save links, summarise articles).
- Routing across several providers, a cost budget, and a limited `admin` role if needed.

## Out of scope (for now)

- Orchestrating coding agents (Claude Code/Codex) like LISA's Fleet.
- An "evolving" persona (Soul/Rêve) and a pixel-art room.
- Publishing to the Play Store / App Store (needs paid developer accounts).
