# Fase 1 — Chat sungguhan (MVP)

> Status: siap dimulai. Lingkungan: laptop (Laragon + PostgreSQL), belum VPS.
> Konteks: [ARCHITECTURE.md](ARCHITECTURE.md) · [ROADMAP.md](ROADMAP.md)

## Tujuan

User baru bisa **daftar dari HP**, **memverifikasi email**, **chat dengan model AI gratis**
yang dipilih admin, melihat jawaban **mengalir per potongan**, dan **riwayatnya sama di semua
HP** yang login dengan akun tersebut, ter-update secara realtime. Admin mengatur provider,
model, user, dan kuota dari **Lumi Console**.

## Di luar cakupan Fase 1

Tools & agent, izin aksi, memori, Lumi Bridge, suara, sidik jari, login Google, push
notification, deploy VPS. Kartu tool dan izin di app tetap ada di kode tapi belum dipakai.

---

## 0. Persiapan repo

- [x] Repo GitHub `RadhitaRayy/LUMI` di-clone ke `C:\Work\lumi`; monorepo `app/`, `docs/`, `design/`.
- [x] Identitas teknis diganti: paket Dart `lumi`, application ID / bundle ID
  `io.github.radhitarayy.lumi`. App lama (`dev.juru.juru`) di HP dihapus manual karena terpasang
  sebagai aplikasi terpisah.
- [x] App tetap lulus analyze dan test setelah dipindah.
- [x] PostgreSQL lokal (Laragon 18.7): user `lumi`, database `lumi` dan `lumi_test`.
- [x] Scaffold `core/`: Laravel 13.44 + starter kit React (Inertia), terhubung ke PostgreSQL,
  migrasi awal jalan, `npm run build` sukses, 42 test bawaan lulus.
- [ ] Email dev: sementara `MAIL_MAILER=log` (kode muncul di `storage/logs`); Mailpit menyusul.
- [ ] Ganti PHPUnit ke Pest (installer gagal di langkah ini karena download dari GitHub timeout).

## 1. Lumi Core (Laravel)

### Setup

- Dibuat dari **starter kit React resmi Laravel** (Inertia + React + TypeScript + Tailwind +
  shadcn/ui), ditambah Sanctum (API mobile), Reverb (realtime), dan Prism PHP. Versi dicek saat instalasi.
- Database PostgreSQL. Semua endpoint mobile di bawah `/api/v1`, respons JSON, error dengan
  `code` yang stabil.

### Database

| Tabel | Kolom penting |
|---|---|
| `users` | `name`, `email`, `email_verified_at`, `password`, `role` (`superadmin`/`user`), `is_blocked`, `daily_quota` (nullable → pakai default) |
| `personal_access_tokens` | bawaan Sanctum; satu token per perangkat (`name` = nama perangkat), `last_used_at` |
| `auth_codes` | `user_id`, `purpose` (`verify_email`/`reset_password`), `code_hash`, `expires_at`, `attempts`, `used_at` |
| `conversations` | `id` (ULID), `user_id`, `title`, `last_message_at`, timestamps |
| `messages` | `id` (ULID), `conversation_id`, `role` (`user`/`assistant`), `content`, `status` (`complete`/`error`/`cancelled`), `provider`, `model`, `input_tokens`, `output_tokens`, timestamps |
| `llm_providers` | `name`, `driver` (`openrouter`/`openai_compatible`/...), `base_url`, `api_key` (cast `encrypted`), `is_enabled` |
| `llm_models` | `provider_id`, `model_id`, `label`, `is_default`, `supports_tools`, `is_enabled` |
| `user_ai_keys` | `user_id` (unik), `driver` (`openrouter`/`openai_compatible`), `base_url`, `api_key` (cast `encrypted`), `key_last4`, `model_id`, `is_active`, `last_validated_at`, `last_error` |
| `llm_usages` | `user_id`, `conversation_id`, `key_source` (`platform`/`user`), `provider`, `model`, `input_tokens`, `output_tokens`, `latency_ms`, `status`, `error_code` |
| `app_settings` | `registration_open`, `require_email_verification`, `default_daily_quota`, `system_prompt` |

### API — akun & sesi

| Method & path | Fungsi |
|---|---|
| `POST /auth/register` | `name`, `email`, `password`, `device_name` → `{user, token}` dan kirim kode verifikasi. `403 registration_closed` jika pendaftaran ditutup. |
| `POST /auth/login` | `email`, `password`, `device_name` → `{user, token}`. `403 account_blocked` untuk user diblokir. |
| `POST /auth/email/verify` | `code` → tandai email terverifikasi. |
| `POST /auth/email/resend` | Kirim ulang kode (dibatasi, mis. 1 per menit). |
| `POST /auth/password/forgot` | `email` → kirim kode reset. Respons selalu sama walau email tidak terdaftar. |
| `POST /auth/password/reset` | `email`, `code`, `password` → ganti password dan **cabut semua token** (semua perangkat keluar). |
| `POST /auth/logout` | Cabut token perangkat ini. |
| `GET /me` · `PATCH /me` | Profil (nama), status verifikasi, sisa kuota hari ini. |
| `PUT /me/password` | Ganti password (butuh password lama). |
| `GET /devices` | Daftar perangkat aktif (nama, terakhir dipakai, penanda "perangkat ini"). |
| `DELETE /devices/{id}` | Keluarkan perangkat lain. |

### API — kunci AI milik user (BYOK)

| Method & path | Fungsi |
|---|---|
| `GET /me/ai-key` | Status key milik user: provider, model, aktif, `key_last4`, terakhir divalidasi. **Tidak pernah** mengembalikan key. |
| `PUT /me/ai-key` | Simpan/ganti key: `driver`, `base_url` (untuk NIM / kompatibel OpenAI), `api_key`, `model_id`. Key divalidasi dulu dengan panggilan kecil ke provider; gagal → `422 ai_key_invalid`. |
| `POST /me/ai-key/test` | Uji ulang key yang tersimpan. |
| `PATCH /me/ai-key` | Aktif/nonaktifkan tanpa menghapus. |
| `DELETE /me/ai-key` | Hapus key; user kembali memakai key platform (dengan kuota). |

`GET /me` menyertakan `ai_key_source` (`platform`/`user`) dan sisa kuota (hanya relevan untuk key platform).

Kode verifikasi/reset: 6 digit, disimpan sebagai hash, berlaku 15 menit, maksimal 5 percobaan.

### API — percakapan

| Method & path | Fungsi |
|---|---|
| `GET /conversations` | Daftar milik user, terbaru dulu, paginasi, `?q=` untuk cari. |
| `POST /conversations` | Buat percakapan baru. |
| `GET /conversations/{id}` | Detail + pesan. |
| `PATCH /conversations/{id}` | Ganti judul. |
| `DELETE /conversations/{id}` | Hapus. |
| `POST /conversations/{id}/messages` | Kirim pesan; respons **SSE** (lihat di bawah). Butuh email terverifikasi (`403 email_unverified`) jika diwajibkan. |

Semua endpoint kecuali register/login/forgot/reset butuh `Authorization: Bearer <token>`.
Akses percakapan milik user lain → `404`.

### Streaming SSE (ke perangkat pengirim)

```
event: message.start   data: {"message_id":"01J...","model":"..."}
event: delta           data: {"text":"potongan teks"}
event: message.end     data: {"input_tokens":123,"output_tokens":45}
event: error           data: {"code":"provider_error","message":"..."}
```

- Pesan user disimpan sebelum memanggil provider; pesan asisten disimpan saat selesai
  (atau dengan `status=error`/`cancelled` jika gagal/terputus).
- Judul percakapan diisi otomatis dari pesan pertama (dipotong), tanpa panggilan AI tambahan.

### Realtime antar perangkat (Reverb)

- Channel privat `private-user.{id}`, diotorisasi dengan token Sanctum.
- Event yang disiarkan:

| Event | Kapan | Isi |
|---|---|---|
| `conversation.created` | Percakapan baru | ringkasan percakapan |
| `conversation.updated` | Judul berubah / pesan baru selesai | ringkasan + `last_message_at` |
| `conversation.deleted` | Percakapan dihapus | `id` |
| `message.created` | Pesan user tersimpan / jawaban asisten selesai | pesan lengkap |
| `session.revoked` | Perangkat dikeluarkan / password direset | `token_id` → perangkat itu kembali ke layar Masuk |

- Fase 1 tidak menyiarkan potongan teks per token ke perangkat lain; perangkat lain menerima
  jawaban lengkap saat selesai.

### LLM Gateway

- Interface tunggal di Core (mis. `App\Llm\Gateway`) yang memilih **sumber key** lalu memanggil
  Prism. Kode lain tidak tahu provider mana yang dipakai.
- Urutan pemilihan: key milik user yang aktif → kalau tidak ada, provider & model default platform
  dari database. Kalau key user gagal, kirim error yang jelas (`user_key_error`) — tidak diam-diam
  pindah ke key platform.
- System prompt dari `app_settings`, riwayat dibatasi N pesan terakhir supaya muat di konteks.
- Error provider (kuota habis, key salah, timeout, model tidak tersedia) dipetakan ke `code` yang jelas.

### Kuota & rate limit

- Kuota harian = jumlah pesan user per hari (Asia/Jakarta) **yang memakai key platform**. Habis →
  `429 quota_exceeded`, dengan petunjuk bahwa user bisa memasang key sendiri. Pesan dengan key
  milik user tidak dihitung kuota (tetap kena rate limit).
- Rate limit login, register, kirim ulang kode, lupa password, dan kirim pesan.
- User diblokir → semua request `403 account_blocked`.

### Superadmin pertama

- Perintah artisan untuk membuat/menjadikan superadmin (mis. `php artisan lumi:make-superadmin email`).
  Superadmin tidak bisa dibuat lewat pendaftaran.

## 2. Lumi Console (Inertia + React, `/console`)

Hanya `role=superadmin` (pemilik Lumi), login dengan sesi web Laravel. Dibangun dengan komponen shadcn/ui,
TanStack Table untuk tabel (cari, filter, paginasi server-side), dan Recharts untuk grafik.
Tampilan mengikuti identitas Lumi App (mode gelap, aksen lime, font Space Grotesk / Inter /
JetBrains Mono). Desain Console dibuat dulu di kanvas sebelum diimplementasi.

| Halaman | Isi |
|---|---|
| Dashboard | Kartu ringkasan (user, pesan hari ini, token hari ini, error), grafik pesan & token 14 hari, error terakhir |
| Users | Daftar, cari, status verifikasi, blokir/buka, atur kuota, lihat & cabut perangkat, tanda "pakai key sendiri" (key-nya tidak pernah ditampilkan) |
| Provider AI | CRUD provider + API key (disembunyikan setelah disimpan) + tombol **Tes koneksi** |
| Model | CRUD model, tandai default, aktif/nonaktif |
| Pengaturan | Pendaftaran buka/tutup, wajib verifikasi email, kuota default, system prompt |
| Log pemakaian | Filter per user/model/tanggal, status & error |

## 3. Lumi App (Flutter)

- Pindah ke `app/`. Alamat Core lewat `--dart-define=API_BASE_URL=...`
  (dev: IP laptop di LAN atau `adb reverse tcp:8000 tcp:8000`).
- **Riverpod** untuk state; `ApiClient` + token di `flutter_secure_storage`; klien Reverb (WebSocket).
- **Layar baru** (didesain dulu di kanvas): Verifikasi email (input kode 6 digit + kirim ulang),
  Lupa password (email → kode + password baru), Perangkat aktif, Profil / ganti password,
  Kunci AI saya.
- **Masuk/Daftar** memanggil Core; error validasi (`422`) tampil per field; pesan khusus untuk
  `registration_closed`, `account_blocked`, `email_unverified`.
- **Auth gate:** buka app → token valid & terverifikasi → Chat; belum terverifikasi → Verifikasi
  email; tidak ada token → Masuk. Event `session.revoked` → kembali ke Masuk.
- **Chat:** kirim pesan, baca SSE, teks mengalir, indikator mengetik, tombol berhenti, pesan error
  yang jelas (kuota habis, jaringan, provider).
- **Riwayat:** daftar dari server, cari, buka percakapan lama, hapus, percakapan baru.
  Ter-update realtime dari perangkat lain; disegarkan saat app kembali aktif.
- **Kunci AI saya** (Pengaturan): pilih provider (OpenRouter / NVIDIA NIM / kompatibel OpenAI),
  tempel API key, pilih model, tombol uji; tampil status aktif + 4 karakter terakhir; hapus key.
  Di layar Chat ada penanda sumber key dan sisa kuota saat memakai key platform.
- Tombol "sidik jari" dan "Google" di layar Masuk disembunyikan dulu.
- `DemoAgent` dihapus atau hanya dipakai di test.

## 4. Provider gratis untuk uji coba

Dipasang lewat Console oleh admin; **key tidak pernah di-commit**.

| Urutan | Provider | Cara sambung |
|---|---|---|
| 1 | **OpenRouter** (model berlabel `:free`) | Driver OpenRouter bawaan Prism |
| 2 | **NVIDIA NIM** (build.nvidia.com) | Endpoint kompatibel OpenAI (base URL kustom) |

Yang dicek saat implementasi: batas pemakaian gratis, dukungan streaming dan tool calling per
model, serta kebijakan data (tier gratis bisa memakai data untuk pelatihan — jangan kirim data
sensitif saat uji coba).

## 5. Pengujian

- **Core:** Pest feature test untuk register/login/blokir/pendaftaran ditutup, verifikasi email &
  reset password (kode salah, kedaluwarsa, terlalu banyak percobaan), perangkat & pencabutan token,
  kepemilikan percakapan, kuota, SSE dengan provider palsu (fake Prism), dan event broadcast
  (`Event::fake`) — tanpa memanggil AI sungguhan.
- **Console:** feature test akses admin-only dan aksi utama (blokir user, simpan provider,
  ubah pengaturan); `npm run build` dan type-check TypeScript lulus.
- **App:** widget test dengan `ApiClient` tiruan (login, verifikasi, error, chat streaming,
  riwayat, event realtime).
- **Manual:** dua perangkat (HP + browser/emulator) dengan akun yang sama → chat di satu, muncul di
  yang lain; keluarkan satu perangkat dari perangkat lainnya.

## 6. Definition of Done

- [ ] User baru bisa daftar, menerima kode, memverifikasi email, dan masuk dari HP.
- [ ] Lupa password lewat kode berhasil dan mengeluarkan semua perangkat.
- [ ] Token tersimpan aman; keluar mencabut token; perangkat lain bisa dikeluarkan dari daftar perangkat.
- [ ] Chat dengan model gratis yang dipilih di Console, jawaban mengalir per potongan.
- [ ] Riwayat sama di dua perangkat dengan akun yang sama dan ter-update realtime.
- [ ] User tidak bisa melihat data milik orang lain (API maupun channel realtime).
- [ ] Kuota harian, blokir user, sakelar pendaftaran, dan wajib verifikasi dari Console langsung berlaku.
- [ ] API key tersimpan terenkripsi dan tidak pernah muncul di respons API.
- [ ] Ganti provider/model default di Console (OpenRouter ↔ NVIDIA NIM) tanpa mengubah kode.
- [ ] User bisa memasang key sendiri di app; setelah itu chat memakai key-nya dan tidak memotong kuota;
  key tidak pernah muncul di respons API maupun di Console.
- [ ] Test Core, Console, dan App lulus; `flutter analyze` bersih.

## 7. Urutan kerja

1. Persiapan repo: git, monorepo, PostgreSQL, Mailpit.
2. Desain di kanvas: layar app baru (verifikasi, lupa password, perangkat) dan Lumi Console.
3. Core: setup, migrasi, auth API (register, login, verifikasi, reset, perangkat) + test.
4. Core: LLM Gateway + endpoint chat SSE + test dengan provider palsu.
5. Core: Reverb + event broadcast + otorisasi channel + test.
6. Console: layout + login admin, provider, model, user, pengaturan, log.
7. Uji dengan OpenRouter, lalu NVIDIA NIM.
8. App: Riverpod, ApiClient, auth gate, Masuk/Daftar/Verifikasi/Lupa password.
9. App: chat SSE, Riwayat, realtime, perangkat aktif.
10. Uji end-to-end dengan dua perangkat, rapikan, perbarui dokumen.

## Keputusan

- [x] Struktur repo: **monorepo** (`app/` + `core/`).
- [x] Database: **PostgreSQL** (dev & produksi).
- [x] Verifikasi email & lupa password: **masuk Fase 1** (kode 6 digit).
- [x] State management app: **Riverpod**.
- [x] Sinkron realtime antar perangkat: **masuk Fase 1** (Reverb).
- [x] Provider uji coba: **OpenRouter**, lalu **NVIDIA NIM**.
- [x] BYOK: **campuran** (key platform + kuota, dan key milik user di app), masuk Fase 1.
- [x] Console hanya untuk **superadmin** (pemilik); peran Fase 1: `superadmin` + `user`.
- [ ] Layanan SMTP produksi (ditentukan di Fase 3).
