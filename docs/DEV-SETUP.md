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

## Perangkat uji

- Samsung Galaxy A56 (SM-A566B), Android, lewat USB.
