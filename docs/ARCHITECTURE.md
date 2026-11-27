# Lumi architecture

> Status: design agreed on 2026-11-25. Implementation starts with [Phase 1](PHASE-1.md).

**Lumi — Light up your day.**

Lumi is a personal AI assistant with a mobile app (Android + iOS) as its main interface, a central
backend on a VPS, and an admin dashboard for settings. The pattern is inspired by
[LISA](https://github.com/oratis/LISA) (MIT): your own server + a companion app + BYOK + action
approval. Lumi does **not** fork LISA; LISA is centred on macOS and is far larger than Lumi needs.

## Components

| Name | What | Technology | Where |
|---|---|---|---|
| **Lumi App** | The everyday app: chat, voice, action approval, history, memory | Flutter (Android, iOS, web/PWA) | The user's phone |
| **Lumi Core** | Backend: API, accounts, device sessions, history, memory, agent loop, realtime | Laravel | VPS (dev: Laragon) |
| **LLM Gateway** | The layer inside Core that forwards requests to AI providers according to BYOK | Prism PHP | Part of Core |
| **Lumi Console** | Admin dashboard: BYOK, models, users, quotas, tools & permissions, audit, cost | Inertia + React + shadcn/ui | Part of Core (`/console`) |
| **Lumi Bridge** | A small program that runs tools on another machine (e.g. a laptop) over an outbound connection to Core | Node.js | Laptop / bot server (Phase 4) |

```
                ┌──────────────────── VPS: Lumi Core (Laravel) ────────────────────┐
 Lumi App ──────▶  REST API (Sanctum)        Lumi Console (React, admin only)       │
 (phone A, B) SSE│  Agent loop + tools        BYOK · users & roles · quota · audit   │
            ◀───┤  PostgreSQL · Queue        LLM Gateway (Prism) ─────────────────────┼──▶ AI providers
            ◀───┤  Reverb (WebSocket)                                                 │    (OpenRouter,
                └────────────────────────────────────▲─────────────────────────────┘     NVIDIA NIM, ...)
                                                     │ outbound WebSocket
                                          Lumi Bridge (laptop, optional, Phase 4)
                                          → pm2 · logs · allowlisted scripts · git pull
```

## Repo layout (monorepo)

```
lumi/      github.com/RadhitaRayy/LUMI · local: C:\Work\lumi
├── app/      Lumi App (Flutter)
├── core/     Lumi Core (Laravel) + Lumi Console (Inertia/React)
├── bridge/   Lumi Bridge (Node.js) — Phase 4
├── design/   UI design sources (canvas) and brand
└── docs/     These documents
```

One repo because there is one developer, and API changes almost always come with app changes.

## Stack

- **Core:** Laravel (latest when Phase 1 started), Sanctum (a token per device), Prism PHP
  (multi-provider LLM, tool calling, streaming), Reverb (realtime WebSocket), Queue + Scheduler,
  **PostgreSQL** (dev & production), transactional email (dev: Mailpit / log, production: SMTP
  from an email service).
- **Console:** Laravel's official React starter kit — Inertia + React + TypeScript + Tailwind +
  shadcn/ui. The look follows the Lumi App: dark mode, lime accent `#B5F23D`, amber `#F5B544` for
  actions that need approval, Space Grotesk / Inter / JetBrains Mono. Console sign-in uses Laravel's
  web session (not the mobile token).
- **App:** Flutter 3.50 (Dart 3.14), `material_ui`, `google_fonts`, **Riverpod** (app state),
  `http`, `flutter_secure_storage` (token), `shared_preferences` (language), `web_socket_channel`
  (Reverb), ARB localisation (English + Indonesian). Later phases: `local_auth`, `speech_to_text`, FCM.
- **Bridge:** Node.js 22 + TypeScript (Phase 4).
- **Infrastructure (Phase 3):** a small Ubuntu VPS (2 vCPU, 2–4 GB RAM), Docker Compose, Caddy
  (automatic HTTPS), a domain, scheduled database backups.

## Accounts, sessions and sync across devices

- **The server is the source of truth.** Conversations, messages and (later) memories are stored
  per **user** in PostgreSQL, not per phone. Any phone signed in to the same account sees the same data.
- **A session = a Sanctum token per device.** Signing in on phone A and phone B gives two tokens
  for the same user. The token lives in `flutter_secure_storage`, so the app stays signed in when
  reopened. Users can see their **active devices** and sign other devices out.
- **Realtime = Reverb.** Each user has a private channel `private-user.{id}`. When something
  changes (a conversation is created/renamed/deleted, a new message is finished), Core broadcasts an
  event on that channel and all of that user's devices update without refreshing.
- **Riverpod only caches** data already fetched from the server so every screen stays consistent
  (e.g. signing out clears every screen at once). Data is refreshed when the app comes back to the
  foreground.

## Hybrid BYOK and roles

**AI keys (hybrid BYOK):**

| Key source | Who adds it | Who pays | Limit |
|---|---|---|---|
| **Platform key** | The superadmin, in Lumi Console | Lumi's owner | A daily quota per user (free, limited) |
| **User's own key** | The user, in the app (Settings → My AI key) | That user | No Lumi quota (rate limits only) |

- New users can chat right away on the platform key within the quota.
- If the user has an active, valid key of their own, the LLM Gateway uses it first. If the user's
  key fails (wrong key, provider quota used up), the app says so; it does not silently fall back to
  the platform key.
- The user's key is sent once from the app to Core, stored encrypted per user, and **never sent
  back** (the app only sees the last 4 characters).

**Roles:**

| Role | Who | Access |
|---|---|---|
| `superadmin` | Lumi's owner/developer | Full Lumi Console: platform keys, providers & models, settings, users, logs; later Bridge tools |
| `user` | Everyone who signs up | The app only; can add their own AI key |

- **Only the owner uses Lumi Console** (superadmin). There is no per-user dashboard; every account
  setting a user needs is in the app.
- The first superadmin is created with an artisan command, never through sign-up.
- A limited `admin` role (manage users & read logs, no access to keys or settings) can be added
  later if someone helps run Lumi.

## Chat flow (Phase 1)

1. The app sends `POST /api/v1/conversations/{id}/messages` with the device token.
2. Core checks the verified email, rate limits and quota (quota applies to the platform key only),
   then stores the user's message.
3. Core calls the LLM Gateway with the conversation history + system prompt, using the user's key
   if there is one, otherwise the platform key.
4. The answer streams back to the sending device as **Server-Sent Events**.
5. When it finishes, Core stores the assistant message and records token usage.
6. Core broadcasts an event through Reverb so the user's other devices update too.

## Languages

- The app ships in **English and Indonesian** (ARB files in `app/lib/l10n`). It follows the phone's
  language (English for languages Lumi doesn't speak yet) and can be changed in Settings → Language.
- The app sends its language as `Accept-Language` and stores it on the user (`locale`), so Core
  answers errors and validation messages, and sends code emails, in the same language.
- Lumi Console stays Indonesian (owner-only).

## Security principles

- **Platform keys are never sent to the app**; they are stored encrypted (`Crypt`) and can only be
  changed from the Console. **Users' own keys** are stored encrypted per user, never sent back to
  the app (last 4 characters only), and not visible to the superadmin in the Console.
- **Open sign-up, with safeguards:** email verification (6-digit code) before chatting, a daily
  quota per user on the platform key, rate limits, a sign-up open/closed switch, user blocking.
- **Roles:** `superadmin` and `user`. The Console and tools that touch systems (Bridge) are superadmin-only.
- **Private realtime channels** are authorised per user; a device only receives its own user's events.
- **No free-form shell.** System tools only run allowlisted commands.
- **Actions that change a system need the user's approval** in the app, and all of them are audited.
- **The Console** is admin-only, behind HTTPS + sign-in.
- Content from users and AI providers is treated as data, not instructions.

## Decision log

| Date | Decision | Reason |
|---|---|---|
| 2026-11-25 | Backend on **Laravel** (not FastAPI/Node) | The owner knows Laravel best; auth, queues, encryption, realtime and multi-provider LLM (Prism) are all available |
| 2026-11-25 | Product name **Lumi** (formerly Juru, before that Nara), tagline **"Light up your day."** | Name and tagline both mean light; the tagline is short, memorable and warm. Before a public release, check for name/trademark clashes since "Lumi" is a common name |
| 2026-11-25 | Component names: **Lumi Core** (backend), **Lumi Console** (admin), **LLM Gateway** (provider layer), **Lumi Bridge** (laptop) | "Gateway" only fits the layer that forwards to providers; Core also holds accounts, history and memory, and runs the agent |
| 2026-11-25 | Console on **Inertia + React + shadcn/ui**, not Filament | The owner wants an attractive look that fully follows Lumi's identity. Trade-off: every CRUD page is hand-built, so Phase 1 Console pages are kept to a minimum |
| 2026-11-25 | **Monorepo** (`app/`, `core/`, `bridge/`, `docs/`) | One developer; API and app changes land in one commit |
| 2026-11-25 | **PostgreSQL** database (dev & production) | The owner's choice; one database engine everywhere |
| 2026-11-25 | **Open sign-up** with email + password, **no QR** | Other people must be able to use Lumi without standing next to the server |
| 2026-11-25 | **Email verification & forgotten password in Phase 1**, with 6-digit email codes | Open sign-up needs verification to curb abuse; codes are easier in an app than links (no deep links) |
| 2026-11-25 | **One session per device** (Sanctum token) + **history synced** across phones + **realtime via Reverb in Phase 1** | The owner wants the same account on phone A and phone B to show the same history, updated live |
| 2026-11-25 | **Riverpod** for app state | Phase 1 adds sign-in, API calls, streaming and realtime used across many screens |
| 2026-11-25 | Test with free providers: **OpenRouter** (first) and **NVIDIA NIM** (second) | Zero cost during development; two different providers prove the LLM Gateway isn't tied to one |
| 2026-11-26 | **Hybrid BYOK**: platform key (added by the superadmin, with a free per-user quota) + the user's own key (added in the app, no Lumi quota). In Phase 1 | New users can still try Lumi easily; the owner's costs stay under control; users who need more bring their own key |
| 2026-11-26 | **Only the owner uses Lumi Console** (`superadmin`); no per-user dashboard. Phase 1 roles: `superadmin` + `user` | Everything users need is in the app; a per-user dashboard would be a second product nobody needs |
| 2026-11-26 | Brand: **an orange cat with a lantern** (sticker style) + a **geometric `lumi` wordmark** with a lime dot | The owner rejected mascots that feel "AI" (light orbs, sparkles); a kampung cat feels friendly and different from LISA's character. Details: `design/brand/README.md` |
| 2026-11-26 | Web Console **without sign-up, email password reset or account deletion**; superadmin-only sign-in | The Console belongs to one person; the owner's account is managed with `lumi:make-superadmin`, and deleting the only superadmin would lock the Console |
| 2026-11-26 | App **multilingual from Phase 1** (Indonesian + English, follows the phone by default, changeable in Settings); Core stores the user's `locale` for emails and error messages | Lumi's users aren't only Indonesian; adding languages later means digging out every hard-coded string |
| 2026-11-27 | **Docs in English** (the README already was) | One language for the repo, open to contributors who don't read Indonesian |
| 2026-11-27 | **4-layer system prompt** (`.md` core/orchestrator/presets + Console platform policy + DB user persona/memory) | Keeps core guardrails and tool rules strictly above user customization; versioned in git and auditable while still giving users a customizable persona |
| 2026-11-27 | **Single-agent tool loop** (`max_steps = 5`) + **non-blocking `ask` pause/resume** (10-min TTL) | Avoids doubling latency/rate-limit burn on free providers and never blocks PHP workers waiting for phone approval |
| 2026-11-27 | **Dedicated Agent menu** (Persona, Memory, Notes, Tools) in the left drawer, separate from account **Settings** | Keeps Settings focused on account/keys/devices/language and gives agent capabilities room to grow in Phases 4–5 |
| 2026-11-25 | Final backend on a **VPS**; every mobile API goes through the VPS | One access point for all users; the laptop never has to be exposed to the internet |
| 2026-11-25 | Laptop tools through **Lumi Bridge** over an outbound connection | No ports to open on the laptop; the same pattern as LISA's relay |
| 2026-11-25 | Chat answers stream over **SSE**; events between devices go through **Reverb** | SSE is the simplest way to stream an answer to the sender; Reverb tells the other devices |

## Open questions

- Do the owner's bots stay on the laptop (with Bridge) or move to the VPS?
- Which email (SMTP) service to use in production.
