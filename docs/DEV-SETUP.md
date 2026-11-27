# Development setup (Windows)

Notes on the environment installed on 2026-11-25 and the problems already hit.

## Installed

| Tool | Location / version |
|---|---|
| Flutter | `C:\src\flutter` — 3.50.1 stable (Dart 3.14) |
| JDK | Microsoft OpenJDK 17 — `%LOCALAPPDATA%\Programs\Microsoft\jdk-17.0.10.7-hotspot` (user `JAVA_HOME`) |
| Android SDK | `%LOCALAPPDATA%\Android\Sdk` (user `ANDROID_HOME`): cmdline-tools, platform-tools 37.0.3, platforms/android-35 & 36, build-tools 36.0.0, NDK 28.2.13676358 |
| Gradle | 9.5.0 (cache in `%USERPROFILE%\.gradle`) |
| PATH (user) | `C:\src\flutter\bin`, `...\Sdk\platform-tools`, `...\Sdk\cmdline-tools\latest\bin` |

Flutter and Dart analytics are turned off.

## Everyday commands

```powershell
cd C:\Work\lumi\app
flutter pub get
flutter analyze
flutter test
flutter run                    # Android phone plugged in (USB debugging on)
flutter run -d chrome          # try it in the browser
flutter build apk --release    # build\app\outputs\flutter-apk\app-release.apk
dart run flutter_launcher_icons   # regenerate app icons from assets/icon
```

Strings live in `app/lib/l10n/app_en.arb` (template) and `app_id.arb`; `flutter pub get` /
`flutter gen-l10n` regenerates `lib/l10n/gen`.

## Running the app on the phone against the laptop

1. Start Core (API on :8000, queue worker, Reverb on :8090, Vite):
   ```powershell
   $env:Path = "$env:USERPROFILE\.config\herd\bin\php84;$env:Path"
   cd C:\Work\lumi\core; php artisan dev
   ```
2. Forward the ports over USB so `127.0.0.1` on the phone reaches the laptop:
   ```powershell
   adb reverse tcp:8000 tcp:8000
   adb reverse tcp:8090 tcp:8090
   ```
3. Build and install. `API_BASE_URL` defaults to `http://127.0.0.1:8000`; `REVERB_KEY` is
   `REVERB_APP_KEY` from `core\.env` (the public Pusher key, not the secret). Without it the app
   works but realtime sync is off. Use a **release** build to judge smoothness: debug builds run
   unoptimised (JIT) and feel laggy, especially animations.
   ```powershell
   cd C:\Work\lumi\app
   flutter build apk --release --dart-define=REVERB_KEY=<REVERB_APP_KEY>
   adb install -r --user 0 build\app\outputs\flutter-apk\app-release.apk
   ```

Unplugging the cable breaks the `adb reverse` link. To use the app over Wi-Fi instead, make a
**debug** build with `--dart-define=API_BASE_URL=http://<laptop LAN IP>:8000` and run
`php artisan serve --host=0.0.0.0`.

Plain HTTP: release builds allow it only to `127.0.0.1`/`localhost`
(`res/xml/network_security_config.xml`), so they work over `adb reverse` and use HTTPS everywhere
else; debug builds allow it to any host (`src/debug/res/xml/network_security_config.xml`).

### Email in development (Mailpit)

Core sends verification and reset codes over SMTP to Mailpit (`MAIL_MAILER=smtp`, port 1025 in
`core\.env`). Mailpit v1.34 lives in `C:\src\mailpit` (Laragon's `bin\mailpit` folder is empty).
Start it, then read the emails at http://127.0.0.1:8025:

```powershell
& 'C:\src\mailpit\mailpit.exe' --listen 127.0.0.1:8025 --smtp 127.0.0.1:1025
```

If Mailpit isn't running, sign-up and "resend code" fail with a mail error.

## Problems already hit

### `package:flutter/material.dart` is deprecated
Since Flutter 3.47, Material lives in the `material_ui` package. The project template already
adds the dependency. Code imports:

```dart
import 'package:material_ui/material_ui.dart';
```

Mixing the two creates two different `TextTheme` classes (errors in `google_fonts`). Use
`GlobalMaterialLocalizations.delegates` from `material_ui` too, not the one in the generated
`AppLocalizations.localizationsDelegates`.

### `sdkmanager` has been replaced by the Android CLI
`sdkmanager` in the latest cmdline-tools is only a wrapper around the Android CLI and does **not**
understand old `;`-style package names. Use `android.exe` with `/`:

```powershell
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\android.exe" sdk list --all "ndk*"
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358' 'platforms/android-36' 'build-tools/36.0.0'
```

Gradle also fails to install the NDK by itself because of this (`Package ndk not found`), so the
NDK version Flutter asks for must be installed by hand as above. Platform 35 still installs
automatically through Gradle.

### `Unable to establish loopback connection` (Java)
Happens when the TEMP path is too long (Java creates a Unix domain socket in TEMP). Seen in
automated sessions with a long TEMP; a normal terminal shouldn't hit it. Fix:

```powershell
$env:TEMP = 'C:\src\_tmp'; $env:TMP = 'C:\src\_tmp'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\src\_tmp -Djava.io.tmpdir=C:\src\_tmp'
```

### Gradle download stalls
The Gradle distribution comes from GitHub and once stalled at 0 bytes. Fix: download
`gradle-9.5.0-all.zip` by hand (check it against the official `.sha256`) into
`%USERPROFILE%\.gradle\wrapper\dists\gradle-9.5.0-all\<hash>\`, then build again.
The first build after adding Android plugins took ~9 minutes (Maven downloads); later builds ~40 s.

### Two `adb`s
scrcpy ships its own `adb`. If its version differs from platform-tools, the two keep killing each
other's adb server. Close scrcpy while running `flutter run`.

### Phone not detected / "device unauthorized"
Turn on Developer options → USB debugging, plug in again, accept the "Allow USB debugging" prompt
(tick "Always allow from this computer"), and pick the **File transfer** USB mode. Check with
`adb devices -l`.

### Two Lumi icons on the phone (Samsung Dual App)
The Galaxy A56 has Samsung Dual Messenger (user 95) and Secure Folder (user 150). A plain
`adb install` also installs into Dual App, which shows a second icon. Install with `--user 0`; to
remove a copy that landed there: `adb shell pm uninstall --user 95 io.github.radhitarayy.lumi`.

## Lumi Core (Laravel)

| Tool | Notes |
|---|---|
| PHP | **8.4** from Herd: `%USERPROFILE%\.config\herd\bin\php84\php.exe`. The PHP on the default PATH is still 7.4 (Laragon), so put the php84 folder first on PATH before running `php`/`composer`. |
| Composer | `C:\laragon\bin\composer\composer.phar` (2.8) |
| Node / npm | Node 25, npm 11 |
| PostgreSQL | Laragon `C:\laragon\bin\postgresql\postgresql-18.7`, data `C:\laragon\data\postgresql-18`, port 5432. User `lumi` (password only in `core\.env`), databases `lumi` and `lumi_test`. |

```powershell
$env:Path = "$env:USERPROFILE\.config\herd\bin\php84;$env:Path"
cd C:\Work\lumi\core
php artisan serve          # http://localhost:8000
npm run dev                # Vite (React Console)
php vendor/bin/pest        # tests (lumi_test database)
php vendor/bin/phpstan analyse --memory-limit=1G
php vendor/bin/pint --dirty
php artisan lumi:make-superadmin you@email.com   # the owner account for Lumi Console
```

Platform keys are normally added in the Console (Provider & model). From the terminal, the key is
typed hidden, tested against the provider, then stored encrypted:

```powershell
# OpenRouter (free models labelled :free)
php artisan lumi:add-provider openrouter "google/gemma-4-31b-it:free" --name=OpenRouter --label="Gemma 4 31B (free)"
# NVIDIA NIM (OpenAI-compatible)
php artisan lumi:add-provider openai_compatible "meta/llama-3.1-8b-instruct" --name="NVIDIA NIM" --url=https://integrate.api.nvidia.com/v1
```

Notes:
- Paste the key with a **right-click**. In a hidden prompt, Ctrl+V only types the letter `v`, and
  the provider answers "Missing Authentication header". The command rejects input that doesn't
  look like a key and shows the length and last 4 characters of the key it received.
- OpenRouter's list of free models changes often. For example,
  `meta-llama/llama-3.3-70b-instruct:free` was no longer free as of 2026-11-26. Check the current
  list (no key needed): `curl -s https://openrouter.ai/api/v1/models`, then pick an id ending in `:free`.

`PHP_CLI_SERVER_WORKERS=4` in `.env` lets `php artisan serve` handle several requests at once;
with a single worker, one slow streaming answer blocks every other request from the app. Chat
streams lift PHP's 30-second limit to 180 seconds (the provider call times out at 120 seconds), and
answers left `streaming` for over 5 minutes are marked `error` / `interrupted`.

Realtime (Reverb) needs three processes: the API server, `reverb:start` and `queue:work` (events go
through the queue). `php artisan dev` runs them all at once. On this laptop port 8080 is taken by
Laragon's Apache, so local Reverb uses port 8090 (`REVERB_PORT=8090` and `REVERB_SERVER_PORT=8090`
in `.env`). After changing `.env`, restart `queue:work`; an old worker keeps the old values.

Languages: the API answers in the language of the app's `Accept-Language` (`id` or `en`, default
`APP_LOCALE=id`). Translations are in `core/lang/id.json` and `core/lang/{id,en}/validation.php`.

Lumi Console is at `http://127.0.0.1:8000/console` (or `https://core.test/console` through Herd).
Create the owner account first (a one-time password is printed in the terminal; change it after
signing in, under My account):

```powershell
php artisan lumi:make-superadmin you@email.com --name="Your Name"
```

After changing files in `resources/js`, run `npm run build` (or `php artisan dev` for Vite with hot
reload). The TypeScript routes (`resources/js/routes`, `resources/js/actions`) are generated by
Wayfinder during the build and aren't committed.

Starting PostgreSQL if it isn't running (or through the Laragon menu):

```powershell
& 'C:\laragon\bin\postgresql\postgresql-18.7\bin\pg_ctl.exe' -D 'C:\laragon\data\postgresql-18' -l 'C:\laragon\data\postgresql-18.log' start
```

### Slow downloads from GitHub
Composer (and Gradle) download packages from GitHub; on this network large files often time out
(e.g. `phpstan`, 31 MB). Fix: run `composer install` again with
`$env:COMPOSER_MAX_PARALLEL_HTTP = '4'` — files already downloaded stay in Composer's cache.
If Composer finishes installing but doesn't exit, stop it and run `composer dump-autoload --optimize`.

### Git: use 2.51, not Laragon's Git
There are two Gits on PATH. Laragon's (2.37, `C:\laragon\bin\git`) uses an old credential manager
that hangs on push/fetch to GitHub. Git 2.51 at `%LOCALAPPDATA%\Programs\Git\cmd\git.exe` (used by
VS Code/GitHub Desktop) works and already has the GitHub login. Repo:
`https://github.com/RadhitaRayy/LUMI`.

## Test device

- Samsung Galaxy A56 (SM-A566B), Android, over USB.
