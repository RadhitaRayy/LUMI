# Roadmap Lumi

> Disusun 2026-11-25. Fase 1 dan 2 dikerjakan di laptop (Laragon) sambil VPS disiapkan.
> Arsitektur dan alasan keputusan ada di [ARCHITECTURE.md](ARCHITECTURE.md).

| Fase | Tujuan | Status |
|---|---|---|
| 0 | Desain UI + aplikasi demo Flutter | ✅ Selesai (2026-11-25) |
| [1](PHASE-1.md) | Chat sungguhan end-to-end: akun + verifikasi email, riwayat tersinkron realtime antar HP, BYOK provider gratis, Console | ⏳ Berikutnya |
| 2 | Agent, tools, izin aksi, memori | Rencana |
| 3 | Deploy ke VPS + APK release | Rencana |
| 4 | Lumi Bridge (laptop) + fitur HP (sidik jari, suara, push) | Rencana |
| 5 | Otonomi & integrasi (rutinitas, Telegram, kalender, knowledge base) | Rencana |

---

## Fase 0 — Desain & demo ✅

- Desain 7 layar (Masuk, Daftar, Chat, Izin aksi, Mode suara, Tools, Riwayat & memori).
- Aplikasi Flutter dengan data tiruan (`DemoAgent`), sudah jalan di Android (Galaxy A56) dan web.
- `flutter analyze` bersih, 6 test lulus.

## Fase 1 — Chat sungguhan (MVP)

Rincian lengkap: [PHASE-1.md](PHASE-1.md).

- **Repo:** monorepo (`app/` + `core/`), PostgreSQL, Mailpit untuk email dev.
- **Core:** daftar bebas + verifikasi email & lupa password (kode 6 digit), sesi per perangkat
  (Sanctum) + daftar perangkat aktif, percakapan & pesan, chat streaming SSE, sinkron realtime
  antar perangkat (Reverb), kuota harian + rate limit, LLM Gateway (Prism) yang diuji dengan
  OpenRouter lalu NVIDIA NIM.
- **Console (Inertia + React + shadcn/ui):** provider & API key (terenkripsi), model,
  user (verifikasi, blokir, kuota, peran, perangkat), pengaturan, log pemakaian.
- **App:** Riverpod; Masuk/Daftar/Verifikasi/Lupa password terhubung ke Core; chat asli
  menggantikan `DemoAgent`; Riwayat dari server, ter-update realtime; perangkat aktif.

**Selesai jika:** user baru bisa daftar dan memverifikasi email dari HP, chat dengan model
gratis yang dipilih admin, jawaban mengalir per potongan, riwayat sama dan ter-update realtime
di dua HP dengan akun yang sama, dan kuota/blokir/pengaturan dari Console berlaku.

## Fase 2 — Agent, tools, dan izin

- Framework tool calling di Core (lewat Prism) + registry tool dengan mode `auto` / `ask`.
- Tool aman di server: `catatan` (simpan/cari), `memori` (ingat/lupa), `waktu`, `web_search`
  (jika ada API gratis yang layak).
- Alur izin end-to-end: aksi `ask` dikirim ke app (Reverb, sudah ada sejak Fase 1), user menyetujui/menolak,
  agent melanjutkan. Semua aksi masuk **log audit**.
- Memori per user: layar Memori di app terhubung, bisa dihapus.
- Console: kelola tools & izin per peran, lihat audit log.
- Kartu tool di chat (`ToolCallCard`, `PendingActionCard`) memakai data asli.

**Selesai jika:** agent bisa memilih tool sendiri, aksi `ask` menunggu persetujuan dari HP,
dan memori yang disimpan dipakai di percakapan berikutnya.

## Fase 3 — Deploy ke VPS

- VPS Ubuntu + Docker Compose (Core, PostgreSQL, queue worker, Reverb) + Caddy (HTTPS) + domain.
- Layanan email SMTP produksi untuk kode verifikasi dan reset password.
- Backup database terjadwal, log, monitoring dasar (uptime).
- Konfigurasi produksi: env terpisah, `APP_DEBUG=false`, rate limit, CORS.
- App: build APK release mengarah ke domain VPS; tambah izin `INTERNET` di manifest release
  (template Flutter hanya memasangnya di debug/profile).
- iOS: PWA (Add to Home Screen) atau IPA via CI macOS + sideload.

**Selesai jika:** app di HP memakai Core di VPS lewat HTTPS tanpa laptop menyala.

## Fase 4 — Lumi Bridge & fitur HP

- **Bridge** (Node.js): daemon di laptop/server bot, koneksi WebSocket keluar ke Core,
  autentikasi token per bridge, tool khusus admin:
  `cek_status_bot`, `baca_log`, `restart_bot` (izin), `jalankan_script` (daftar putih, izin),
  `git_pull` (izin). Status online/offline tampil di app dan Console.
- **HP:** buka dengan sidik jari/Face ID (`local_auth`), input suara bahasa Indonesia
  (`speech_to_text`), push notification (FCM), tampilan offline.

**Selesai jika:** dari HP, admin bisa melihat status bot di laptop dan me-restart-nya
dengan persetujuan, dan notifikasi izin masuk walau app tertutup.

## Fase 5 — Otonomi & integrasi

- Rutinitas terjadwal (Scheduler): mis. "cek bot tiap pagi, kabari kalau ada error".
- Notifikasi proaktif dengan jam tenang, anti-duplikat, dan batas kirim.
- Channel Telegram (chat dengan Lumi lewat bot Telegram).
- Konektor: Google Calendar (baca dulu), kemudian lainnya.
- Knowledge base pribadi (simpan link, ringkas artikel).
- BYOK per user, routing ke beberapa provider, budget biaya.

## Di luar cakupan (untuk sekarang)

- Orkestrasi coding agent (Claude Code/Codex) seperti Fleet di LISA.
- Persona yang "berevolusi" (Soul/Rêve) dan room pixel-art.
- Rilis ke Play Store / App Store (butuh akun developer berbayar).
