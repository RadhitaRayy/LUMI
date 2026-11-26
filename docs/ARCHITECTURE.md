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

## BYOK campuran dan peran

**Kunci AI (BYOK campuran):**

| Sumber key | Siapa memasang | Siapa membayar | Batas |
|---|---|---|---|
| **Key platform** | Superadmin, di Lumi Console | Pemilik Lumi | Kuota harian per user (gratis, terbatas) |
| **Key milik user** | User sendiri, di app (Pengaturan → Kunci AI saya) | User itu sendiri | Tidak dibatasi kuota Lumi (hanya rate limit) |

- User baru langsung bisa chat dengan key platform dalam batas kuota.
- Kalau user memasang key sendiri yang aktif dan valid, LLM Gateway memakai key itu lebih dulu.
  Kalau key user gagal (salah/kuota provider habis), app memberi tahu; tidak diam-diam pindah ke
  key platform.
- Key user dikirim sekali dari app ke Core, disimpan terenkripsi per user, dan **tidak pernah
  dikirim balik** (app hanya melihat 4 karakter terakhir).

**Peran:**

| Peran | Siapa | Akses |
|---|---|---|
| `superadmin` | Pemilik/developer Lumi | Lumi Console penuh: key platform, provider & model, pengaturan, user, log; nanti tool Bridge |
| `user` | Semua yang mendaftar | Hanya app; bisa memasang key AI miliknya sendiri |

- **Lumi Console hanya dipegang pemilik** (superadmin). Tidak ada dashboard per user; semua
  pengaturan akun user ada di app.
- Superadmin pertama dibuat lewat perintah artisan, tidak bisa lewat pendaftaran.
- Peran `admin` terbatas (kelola user & lihat log, tanpa akses key/pengaturan) bisa ditambahkan
  nanti bila ada yang membantu mengelola.

## Alur chat (Fase 1)

1. App mengirim `POST /api/v1/conversations/{id}/messages` dengan token perangkat.
2. Core memeriksa email terverifikasi, rate limit, dan kuota (kuota hanya untuk key platform),
   lalu menyimpan pesan user.
3. Core memanggil LLM Gateway dengan riwayat percakapan + system prompt, memakai key user bila
   ada, kalau tidak memakai key platform.
4. Jawaban dialirkan balik ke perangkat pengirim sebagai **Server-Sent Events**.
5. Setelah selesai, Core menyimpan pesan asisten dan mencatat pemakaian token.
6. Core menyiarkan event lewat Reverb, sehingga perangkat lain milik user yang sama ikut ter-update.

## Prinsip keamanan

- **Key platform tidak pernah dikirim ke app**; disimpan terenkripsi (`Crypt`) dan hanya bisa
  diubah dari Console. **Key milik user** disimpan terenkripsi per user dan tidak pernah dikirim
  balik ke app (hanya 4 karakter terakhir), tidak terlihat oleh superadmin di Console.
- **Pendaftaran bebas, dengan pengaman:** verifikasi email (kode 6 digit) sebelum bisa chat,
  kuota harian per user untuk key platform, rate limit, sakelar pendaftaran buka/tutup, blokir user.
- **Peran:** `superadmin` dan `user`. Console dan tool yang menyentuh sistem (Bridge) hanya untuk superadmin.
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
| 2026-11-25 | Uji coba pakai provider gratis: **OpenRouter** (pertama) dan **NVIDIA NIM** (kedua) | Biaya nol selama pengembangan; dua provider berbeda membuktikan LLM Gateway tidak terikat satu provider |
| 2026-11-26 | **BYOK campuran**: key platform (dipasang superadmin, dengan kuota gratis per user) + key milik user (dipasang di app, tanpa kuota Lumi). Masuk Fase 1 | User baru tetap mudah mencoba; biaya pemilik terkendali; user yang butuh lebih memakai key sendiri |
| 2026-11-26 | **Lumi Console hanya dipegang pemilik** (`superadmin`); tidak ada dashboard per user. Peran Fase 1: `superadmin` + `user` | Semua kebutuhan user sudah ada di app; dashboard per user = produk kedua yang tidak diperlukan |
| 2026-11-26 | Brand: **karakter kucing oranye berlentera** (gaya stiker) + **logotipe `lumi` geometris** dengan titik lime | Pemilik menolak maskot yang terasa "AI" (bola cahaya, kilau); kucing kampung terasa akrab dan beda dari karakter LISA. Detail: `design/brand/README.md` |
| 2026-11-26 | Console di web **tanpa pendaftaran, reset password email, dan hapus akun**; login hanya superadmin | Console milik satu orang; akun pemilik dikelola lewat `lumi:make-superadmin`, dan menghapus satu-satunya superadmin akan mengunci Console |
| 2026-11-25 | Backend final di **VPS**; semua API mobile lewat VPS | Satu titik akses untuk semua pengguna; laptop tidak perlu dibuka ke internet |
| 2026-11-25 | Tool di laptop lewat **Lumi Bridge** dengan koneksi keluar | Tidak perlu membuka port di laptop; pola yang sama dengan relay di LISA |
| 2026-11-25 | Jawaban chat dialirkan lewat **SSE**; event antar perangkat lewat **Reverb** | SSE paling sederhana untuk aliran jawaban ke pengirim; Reverb untuk memberi tahu perangkat lain |

## Pertanyaan terbuka

- Bot-bot pemilik tetap di laptop (pakai Bridge) atau dipindah ke VPS?
- Layanan email (SMTP) untuk produksi.
