# Setup pengembangan (Windows)

Catatan lingkungan yang dipasang pada 2026-11-25 dan masalah yang sudah ditemui.

## Yang terpasang

| Alat | Lokasi / versi |
|---|---|
| Flutter | `C:\src\flutter` — 3.50.1 stable (Dart 3.14) |
| JDK | Microsoft OpenJDK 17 — `%LOCALAPPDATA%\Programs\Microsoft\jdk-17.0.10.7-hotspot` (`JAVA_HOME` user) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME` user): cmdline-tools, platform-tools 37.0.3, platforms/android-35 & 36, build-tools 36.0.0, NDK 28.2.13676358 |
| Gradle | 9.5.0 (cache di `%USERPROFILE%\.gradle`) |
| PATH (user) | `C:\src\flutter\bin`, `...\Sdk\platform-tools`, `...\Sdk\cmdline-tools\latest\bin` |

Analytics Flutter dan Dart dimatikan.

## Perintah sehari-hari

```powershell
cd C:\Work\lumi\app
flutter pub get
flutter analyze
flutter test
flutter run                    # HP Android tercolok (USB debugging aktif)
flutter run -d chrome          # coba di browser
flutter build apk --release    # build\app\outputs\flutter-apk\app-release.apk
```

## Masalah yang sudah ditemui

### `package:flutter/material.dart` deprecated
Sejak Flutter 3.47, Material dipindah ke paket `material_ui`. Template project sudah
menambahkan dependensinya. Import di kode memakai:

```dart
import 'package:material_ui/material_ui.dart';
```

Mencampur keduanya membuat dua kelas `TextTheme` yang berbeda (error di `google_fonts`).

### `sdkmanager` sudah diganti Android CLI
`sdkmanager` di cmdline-tools terbaru hanya pembungkus Android CLI dan **tidak** mengenali
nama paket lama berformat `;`. Pakai `android.exe` dengan pemisah `/`:

```powershell
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\android.exe" sdk list --all "ndk*"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358' 'platforms/android-36' 'build-tools/36.0.0'
```

Gradle juga gagal memasang NDK sendiri karena masalah ini (`Package ndk not found`), jadi NDK
versi yang diminta Flutter harus dipasang manual seperti di atas. Platform 35 masih bisa
dipasang otomatis oleh Gradle.

### `Unable to establish loopback connection` (Java)
Terjadi kalau path folder TEMP terlalu panjang (Java membuat Unix domain socket di TEMP).
Muncul di sesi otomatis dengan TEMP panjang; di terminal biasa seharusnya tidak. Solusi:

```powershell
$env:TEMP = 'C:\src\_tmp'; $env:TMP = 'C:\src\_tmp'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\src\_tmp -Djava.io.tmpdir=C:\src\_tmp'
```

### Download Gradle macet
Distribusi Gradle diunduh dari GitHub dan sempat macet di 0 byte. Solusi: unduh manual
`gradle-9.5.0-all.zip` (cek dengan file `.sha256` resminya) ke
`%USERPROFILE%\.gradle\wrapper\dists\gradle-9.5.0-all\<hash>\`, lalu build ulang.

### Dua `adb`
scrcpy membawa `adb` sendiri. Kalau versinya beda dengan platform-tools, keduanya saling
mematikan server adb. Tutup scrcpy saat menjalankan `flutter run`.

### HP tidak terdeteksi
Aktifkan Opsi pengembang → Debugging USB, colok ulang, setujui popup "Izinkan debugging USB",
pilih mode USB **Transfer file**. Cek dengan `adb devices -l`.

## Lumi Core (Laravel)

| Alat | Catatan |
|---|---|
| PHP | **8.4** dari Herd: `%USERPROFILE%\.config\herd\bin\php84\php.exe`. PHP di PATH default masih 7.4 (Laragon), jadi taruh folder php84 di depan PATH sebelum menjalankan `php`/`composer`. |
| Composer | `C:\laragon\bin\composer\composer.phar` (2.8) |
| Node / npm | Node 25, npm 11 |
| PostgreSQL | Laragon `C:\laragon\bin\postgresql\postgresql-18.7`, data `C:\laragon\data\postgresql-18`, port 5432. User `lumi` (password hanya di `core\.env`), database `lumi` dan `lumi_test`. |

```powershell
$env:Path = "$env:USERPROFILE\.config\herd\bin\php84;$env:Path"
cd C:\Work\lumi\core
php artisan serve          # http://localhost:8000
npm run dev                # Vite (Console React)
php vendor/bin/pest        # test (database lumi_test)
php vendor/bin/phpstan analyse --memory-limit=1G
php vendor/bin/pint --dirty
php artisan lumi:make-superadmin email@kamu.com   # akun pemilik untuk Lumi Console
```

Memasang key platform (sementara, sampai halaman Console siap). Key diketik tersembunyi,
diuji ke provider, lalu disimpan terenkripsi:

```powershell
# OpenRouter (model gratis berlabel :free)
php artisan lumi:add-provider openrouter "google/gemma-4-31b-it:free" --name=OpenRouter --label="Gemma 4 31B (free)"
# NVIDIA NIM (OpenAI-compatible)
php artisan lumi:add-provider openai_compatible "meta/llama-3.1-8b-instruct" --name="NVIDIA NIM" --url=https://integrate.api.nvidia.com/v1
```

Catatan:
- Paste key dengan **klik kanan**. Di prompt tersembunyi, Ctrl+V hanya mengetik huruf `v`,
  dan provider membalasnya dengan "Missing Authentication header". Perintah ini menolak isian
  yang tidak berbentuk key dan menampilkan panjang serta 4 karakter terakhir key yang diterima.
- Daftar model gratis OpenRouter sering berubah. Contohnya, `meta-llama/llama-3.3-70b-instruct:free`
  sudah tidak gratis lagi per 2026-11-26. Cek daftar terbaru (tanpa key):
  `curl -s https://openrouter.ai/api/v1/models`, lalu pilih id yang berakhiran `:free`.

Realtime (Reverb) butuh tiga proses: server API, `reverb:start`, dan `queue:work` (event dikirim
lewat queue). `php artisan dev` menjalankan semuanya sekaligus. Di laptop ini port 8080 dipakai
Apache bawaan Laragon, jadi Reverb lokal memakai port 8090 (`REVERB_PORT=8090` dan
`REVERB_SERVER_PORT=8090` di `.env`). Setelah mengubah `.env`, restart `queue:work`; worker lama
masih memakai nilai yang lama.

Menyalakan PostgreSQL kalau belum jalan (atau lewat menu Laragon):

```powershell
& 'C:\laragon\bin\postgresql\postgresql-18.7\bin\pg_ctl.exe' -D 'C:\laragon\data\postgresql-18' -l 'C:\laragon\data\postgresql-18.log' start
```

### Download dari GitHub lambat
Composer (dan Gradle) mengunduh paket dari GitHub; di jaringan ini sering timeout untuk file
besar (mis. `phpstan` 31 MB). Solusi: ulangi `composer install` dengan
`$env:COMPOSER_MAX_PARALLEL_HTTP = '4'` — file yang sudah terunduh tersimpan di cache Composer.
Kalau Composer selesai memasang paket tapi tidak keluar, hentikan lalu jalankan
`composer dump-autoload --optimize`.

### Git: pakai versi 2.51, bukan Git Laragon
Ada dua Git di PATH. Git bawaan Laragon (2.37, `C:\laragon\bin\git`) memakai credential manager
lama yang menggantung saat push/fetch ke GitHub. Git 2.51 di
`%LOCALAPPDATA%\Programs\Git\cmd\git.exe` (dipakai VS Code/GitHub Desktop) berjalan normal dan
sudah tersimpan login GitHub-nya. Repo: `https://github.com/RadhitaRayy/LUMI`.

## Perangkat uji

- Samsung Galaxy A56 (SM-A566B), Android, lewat USB.
