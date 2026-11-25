# Arsitektur Lumi

> Status: rancangan, disepakati 2026-11-25. Implementasi dimulai dari [Fase 1](PHASE-1.md).

**Lumi — Light up your day.**

Lumi adalah asisten AI pribadi dengan aplikasi mobile (Android + iOS) sebagai antarmuka
utama, backend terpusat di VPS, dan dashboard admin untuk pengaturan. Polanya terinspirasi
[LISA](https://github.com/oratis/LISA) (MIT): server milik sendiri + aplikasi pendamping +
BYOK + persetujuan aksi. Lumi **tidak** mem-fork LISA; LISA berpusat pada macOS dan
cakupannya jauh lebih besar dari kebutuhan Lumi.

## Komponen

| Nama | Apa | Teknologi | Lokasi |
|---|---|---|---|
| **Lumi App** | Aplikasi yang dipakai sehari-hari: chat, suara, izin aksi, riwayat, memori | Flutter (Android, iOS, web/PWA) | HP pengguna |
| **Lumi Core** | Backend: API, akun, sesi perangkat, riwayat, memori, agent loop, realtime | Laravel | VPS (dev: Laragon) |
| **LLM Gateway** | Lapisan di dalam Core yang meneruskan permintaan ke provider AI sesuai BYOK | Prism PHP | Bagian dari Core |
| **Lumi Console** | Dashboard admin: BYOK, model, user, kuota, tools & izin, audit, biaya | Inertia + React + shadcn/ui | Bagian dari Core (`/console`) |
| **Lumi Bridge** | Program kecil yang menjalankan tool di mesin lain (mis. laptop) lewat koneksi keluar ke Core | Node.js | Laptop / server bot (Fase 4) |

```
                ┌──────────────────── VPS: Lumi Core (Laravel) ────────────────────┐
 Lumi App ──────▶  REST API (Sanctum)        Lumi Console (React, admin saja)       │
 (HP A, HP B) SSE│  Agent loop + tools        BYOK · user & peran · kuota · audit    │
            ◀───┤  PostgreSQL · Queue        LLM Gateway (Prism) ─────────────────────┼──▶ Provider AI
            ◀───┤  Reverb (WebSocket)                                                 │    (OpenRouter,
                └────────────────────────────────────▲─────────────────────────────┘     NVIDIA NIM, ...)
                                                     │ WebSocket keluar
                                          Lumi Bridge (laptop, opsional, Fase 4)
                                          → pm2 · log · script whitelist · git pull
```

## Struktur repo (monorepo)

```
lumi/      github.com/RadhitaRayy/LUMI · lokal: C:\Work\lumi
├── app/      Lumi App (Flutter)
├── core/     Lumi Core (Laravel) + Lumi Console (Inertia/React)
├── bridge/   Lumi Bridge (Node.js) — Fase 4
├── design/   Sumber desain UI (kanvas)
└── docs/     Dokumen ini
```

Satu repo karena satu pengembang, dan perubahan API hampir selalu diikuti perubahan di app.

## Stack

- **Core:** Laravel (versi terbaru saat Fase 1 dimulai), Sanctum (token per perangkat),
  Prism PHP (multi-provider LLM, tool calling, streaming), Reverb (WebSocket realtime),
  Queue + Scheduler, **PostgreSQL** (dev & produksi), email transaksional
  (dev: Mailpit / log, produksi: SMTP dari layanan email).
- **Console:** starter kit React resmi Laravel — Inertia + React + TypeScript + Tailwind +
  shadcn/ui, dengan TanStack Table (tabel) dan Recharts (grafik). Tampilan mengikuti identitas
  Lumi App: mode gelap, aksen lime `#B5F23D`, amber `#F5B544` untuk aksi berizin, font Space
  Grotesk / Inter / JetBrains Mono. Login Console memakai sesi web Laravel (bukan token mobile).
- **App:** Flutter 3.50 (Dart 3.14), `material_ui`, `google_fonts`, **Riverpod** (state di
  dalam app), HTTP client, `flutter_secure_storage` (token), klien WebSocket untuk Reverb.
  Fase berikutnya: `local_auth`, `speech_to_text`, FCM.
- **Bridge:** Node.js 22 + TypeScript (Fase 4).
- **Infrastruktur (Fase 3):** VPS Ubuntu kecil (2 vCPU, 2–4 GB RAM), Docker Compose, Caddy
  (HTTPS otomatis), domain, backup database terjadwal.

## Akun, sesi, dan sinkronisasi antar perangkat

- **Sumber kebenaran = server.** Percakapan, pesan, dan (nanti) memori disimpan per **user**
  di PostgreSQL, bukan per HP. HP mana pun yang login dengan akun yang sama melihat data yang sama.
- **Sesi = token Sanctum per perangkat.** Login di HP A dan HP B menghasilkan dua token milik
  user yang sama. Token disimpan di `flutter_secure_storage`, jadi app tetap login saat dibuka
  lagi. Pengguna bisa melihat **perangkat aktif** dan mengeluarkan perangkat lain.
- **Realtime = Reverb.** Setiap user punya channel privat `private-user.{id}`. Saat ada
  perubahan (percakapan dibuat/diubah/dihapus, pesan baru selesai), Core menyiarkan event ke
  channel itu, dan semua perangkat user tersebut memperbarui tampilannya tanpa ditarik ulang.
- **Riverpod hanya menyimpan sementara** data yang sudah diambil dari server supaya semua layar
  konsisten (mis. logout langsung membersihkan semua layar). Saat app kembali aktif, data
  disegarkan dari server.

## Alur chat (Fase 1)

1. App mengirim `POST /api/v1/conversations/{id}/messages` dengan token perangkat.
2. Core memeriksa email terverifikasi, kuota, dan rate limit, lalu menyimpan pesan user.
3. Core memanggil LLM Gateway dengan riwayat percakapan + system prompt.
4. Jawaban dialirkan balik ke perangkat pengirim sebagai **Server-Sent Events**.
5. Setelah selesai, Core menyimpan pesan asisten dan mencatat pemakaian token.
6. Core menyiarkan event lewat Reverb, sehingga perangkat lain milik user yang sama ikut ter-update.

## Prinsip keamanan

- **API key tidak pernah dikirim ke app.** Key disimpan terenkripsi di database Core
  (`Crypt`) dan hanya bisa diubah dari Console.
- **Pendaftaran bebas, dengan pengaman:** verifikasi email (kode 6 digit) sebelum bisa chat,
  kuota harian per user, rate limit, sakelar pendaftaran buka/tutup, blokir user.
- **Peran:** `admin` dan `user`. Tool yang menyentuh sistem (Bridge) hanya untuk admin.
- **Channel realtime privat** diotorisasi per user; perangkat hanya menerima event miliknya.
- **Tidak ada shell bebas.** Tool sistem hanya menjalankan perintah dari daftar putih.
- **Aksi yang mengubah sistem butuh izin** pengguna di app, dan semuanya masuk log audit.
- **Console** hanya untuk admin, di balik HTTPS + login.
- Data dari pengguna dan provider AI diperlakukan sebagai data, bukan instruksi.

## Log keputusan

| Tanggal | Keputusan | Alasan |
|---|---|---|
| 2026-11-25 | Backend pakai **Laravel** (bukan FastAPI/Node) | Pemilik paling familiar dengan Laravel; auth, queue, enkripsi, realtime, dan multi-provider LLM (Prism) sudah tersedia |
| 2026-11-25 | Nama produk **Lumi** (sebelumnya Juru, sebelumnya lagi Nara), tagline **"Light up your day."** | Nama dan tagline sama-sama bermakna cahaya; tagline singkat, mudah diingat, hangat. Sebelum rilis publik, cek dulu bentrokan nama/merek karena "Lumi" nama yang umum |
| 2026-11-25 | Nama komponen: **Lumi Core** (backend), **Lumi Console** (admin), **LLM Gateway** (lapisan provider), **Lumi Bridge** (laptop) | "Gateway" hanya tepat untuk lapisan yang meneruskan ke provider; Core juga menyimpan akun, riwayat, memori, dan menjalankan agent |
| 2026-11-25 | Console pakai **Inertia + React + shadcn/ui**, bukan Filament | Pemilik ingin tampilan yang menarik dan bisa disesuaikan penuh dengan identitas Lumi. Konsekuensi: tiap halaman CRUD dibuat sendiri, jadi halaman Console Fase 1 dijaga seminimal mungkin |
| 2026-11-25 | **Monorepo** (`app/`, `core/`, `bridge/`, `docs/`) | Satu pengembang; perubahan API dan app masuk dalam satu commit |
| 2026-11-25 | Database **PostgreSQL** (dev & produksi) | Pilihan pemilik; satu jenis database di semua lingkungan |
| 2026-11-25 | **Daftar bebas** dengan email + password, **tanpa QR** | Orang lain harus bisa memakai Lumi tanpa berada di depan server |
| 2026-11-25 | **Verifikasi email & lupa password masuk Fase 1**, dengan kode 6 digit lewat email | Pendaftaran bebas butuh verifikasi untuk menekan penyalahgunaan; kode lebih mudah di app daripada link (tanpa deep link) |
| 2026-11-25 | **Sesi per perangkat** (token Sanctum) + **riwayat tersinkron** antar HP + **realtime lewat Reverb di Fase 1** | Pemilik ingin login yang sama di HP A dan HP B melihat riwayat yang sama dan ter-update langsung |
| 2026-11-25 | **Riverpod** untuk state di dalam app | Fase 1 menambah login, panggilan API, streaming, dan realtime yang dipakai banyak layar |
| 2026-11-25 | **BYOK diatur admin** di Console; uji coba pakai provider gratis: **OpenRouter** (pertama) dan **NVIDIA NIM** (kedua) | Biaya nol selama pengembangan; dua provider berbeda membuktikan LLM Gateway tidak terikat satu provider |
| 2026-11-25 | Backend final di **VPS**; semua API mobile lewat VPS | Satu titik akses untuk semua pengguna; laptop tidak perlu dibuka ke internet |
| 2026-11-25 | Tool di laptop lewat **Lumi Bridge** dengan koneksi keluar | Tidak perlu membuka port di laptop; pola yang sama dengan relay di LISA |
| 2026-11-25 | Jawaban chat dialirkan lewat **SSE**; event antar perangkat lewat **Reverb** | SSE paling sederhana untuk aliran jawaban ke pengirim; Reverb untuk memberi tahu perangkat lain |

## Pertanyaan terbuka

- Bot-bot pemilik tetap di laptop (pakai Bridge) atau dipindah ke VPS?
- BYOK per user (setiap user memasukkan key sendiri) atau hanya key admin?
- Layanan email (SMTP) untuk produksi.
