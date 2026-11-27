<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="design/brand/png/lumi-logo-dark.png">
    <img src="design/brand/png/lumi-logo-light.png" alt="Lumi, the cat with a lantern" width="440">
  </picture>
</p>

# Lumi — Personal AI Agent

> **Light up your day.**

Lumi is a personal AI assistant with a mobile app (Android + iOS) as its main interface,
a **Lumi Core** backend (Laravel) running on a VPS, and an admin dashboard, **Lumi Console**,
for bring-your-own-key (BYOK) setup, users, and quotas. The agent can take actions such as
checking bot status, reading logs, restarting services, or running scripts, and asks for
permission before anything that changes a system.

> **Status: Phase 1 complete.** Lumi Core, Lumi Console, and Lumi App's Phase 1 real-chat MVP are
> built and tested. Phase 2 (AI orchestrator, layered system prompt & user persona, tools,
> approvals, memory) is next. Plan: [Roadmap](docs/ROADMAP.md) · [Phase 1](docs/PHASE-1.md).

## Repository layout

| Folder | Contents |
|---|---|
| [`app/`](app/) | **Lumi App** — Flutter (Android, iOS, web/PWA) |
| [`core/`](core/) | **Lumi Core** + **Lumi Console** — Laravel + Inertia/React |
| `bridge/` | **Lumi Bridge** — Node.js daemon for tools on a laptop/server (Phase 4) |
| [`design/`](design/) | UI design sources (canvas) and the brand |
| [`docs/`](docs/) | Architecture, roadmap, phase specs, dev setup |

The app speaks English and Indonesian; the Console is Indonesian.

## Architecture at a glance

```
Lumi App (phones) ──HTTPS/SSE──▶ Lumi Core (Laravel, VPS) ──▶ AI provider (BYOK)
        ▲                          │  PostgreSQL · Reverb · Lumi Console
        └──── realtime (Reverb) ───┘
                                   ▲ outbound WebSocket
                         Lumi Bridge (laptop, optional)
```

- **Accounts:** open sign-up with email + password, 6-digit email codes for verification and
  password reset, one session token per device.
- **Sync:** conversations live on the server, so every phone signed in to the same account sees
  the same history, updated in realtime.
- **BYOK:** the admin sets AI providers and keys in Lumi Console; keys are encrypted at rest and
  never sent to the app. Development uses free providers (OpenRouter, NVIDIA NIM).

## Documentation

| Document | What's inside |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Components, stack, sessions & sync, security, decision log |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phases 0–5 and their done criteria |
| [docs/PHASE-1.md](docs/PHASE-1.md) | Phase 1 spec: database, API, SSE, realtime, Console, app, definition of done |
| [docs/DEV-SETUP.md](docs/DEV-SETUP.md) | Windows toolchain and known issues |

## Lumi App

| Screen | File |
|---|---|
| Sign in | `app/lib/features/auth/login_screen.dart` |
| Sign up | `app/lib/features/auth/register_screen.dart` |
| Chat | `app/lib/features/chat/chat_screen.dart` |
| Action approval (bottom sheet) | `app/lib/features/chat/confirm_action_sheet.dart` |
| Voice mode | `app/lib/features/voice/voice_screen.dart` |
| Tools & connections | `app/lib/features/tools/tools_screen.dart` |
| History & memory | `app/lib/features/history/history_screen.dart` |

Theme and colors live in `app/lib/theme/app_theme.dart`.

```powershell
cd app
flutter pub get
flutter run -d chrome        # try it in a browser
flutter run                  # connected Android phone (USB debugging)
flutter test
```

### Installing without a store account

- **Android:** `flutter build apk --release`, then install
  `app/build/app/outputs/flutter-apk/app-release.apk` on the phone.
- **iOS (PWA):** `flutter build web`, host `app/build/web`, open it in Safari and choose
  *Share → Add to Home Screen*.
- **iOS (native):** build an unsigned IPA on a macOS CI service, then sideload it with a free
  Apple ID (it has to be reinstalled every 7 days).

## Roadmap

1. **Phase 1:** accounts with email verification, streaming chat, history synced across phones
   in realtime, BYOK with free AI providers, Lumi Console.
2. **Phase 2:** agent and tools, action approvals, memory.
3. **Phase 3:** deploy Core to a VPS, release APK.
4. **Phase 4:** Lumi Bridge on the laptop, biometric unlock, voice input, push notifications.
5. **Phase 5:** scheduled routines, Telegram channel, calendar, knowledge base.

Details: [docs/ROADMAP.md](docs/ROADMAP.md).

## License

[MIT](LICENSE)
