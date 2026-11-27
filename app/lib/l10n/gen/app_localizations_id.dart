// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTagline => 'Light up your day.';

  @override
  String appVersionLine(String version) {
    return 'Lumi $version · Light up your day.';
  }

  @override
  String get cancel => 'Batal';

  @override
  String get save => 'Simpan';

  @override
  String get back => 'Kembali';

  @override
  String get retry => 'Coba lagi';

  @override
  String get later => 'Nanti saja';

  @override
  String get splashSkip => 'Langsung ke Lumi';

  @override
  String get errorNetwork =>
      'Tidak bisa terhubung ke Lumi. Cek koneksi lalu coba lagi.';

  @override
  String get errorUnknown => 'Ada yang salah. Coba lagi.';

  @override
  String get errorInvalidCredentials => 'Email atau password salah.';

  @override
  String get errorAccountBlocked => 'Akun kamu diblokir. Hubungi admin Lumi.';

  @override
  String get errorRegistrationClosed =>
      'Pendaftaran sedang ditutup. Coba lagi nanti.';

  @override
  String get errorCodeExpired => 'Kode sudah kedaluwarsa. Minta kode baru.';

  @override
  String get errorCodeAttempts => 'Terlalu banyak percobaan. Minta kode baru.';

  @override
  String get errorCodeInvalid => 'Kode tidak valid. Minta kode baru.';

  @override
  String get errorTooManyRequests =>
      'Terlalu banyak permintaan. Coba lagi sebentar.';

  @override
  String get errorNoModel => 'AI Lumi belum diatur. Coba lagi nanti.';

  @override
  String get loginGreeting => 'Halo lagi!';

  @override
  String get loginSubtitle => 'Masuk untuk lanjut ngobrol dengan Lumi.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailHint => 'kamu@email.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Minimal 8 karakter';

  @override
  String get showPassword => 'Tampilkan password';

  @override
  String get hidePassword => 'Sembunyikan password';

  @override
  String get forgotPasswordLink => 'Lupa password?';

  @override
  String get signIn => 'Masuk';

  @override
  String get noAccount => 'Belum punya akun?';

  @override
  String get signUpFree => 'Daftar gratis';

  @override
  String get fieldRequired => 'Isi dulu bagian ini.';

  @override
  String get emailInvalid => 'Sepertinya ini bukan alamat email.';

  @override
  String get catWaving => 'Lumi si kucing melambai';

  @override
  String get registerTitle => 'Buat akun Lumi';

  @override
  String get registerSubtitle =>
      'Gratis. Kami kirim kode ke email kamu untuk memastikan itu benar milikmu.';

  @override
  String get nameLabel => 'Nama panggilan';

  @override
  String get nameHint => 'Biar Lumi tahu harus panggil apa';

  @override
  String get pwStrengthEmpty => 'Minimal 8 karakter';

  @override
  String pwStrengthShort(int count) {
    return 'Kurang $count karakter lagi';
  }

  @override
  String get pwStrengthWeak => 'Lumayan. Tambah angka biar lebih kuat.';

  @override
  String get pwStrengthGood => 'Bagus, tinggal sedikit lagi.';

  @override
  String get pwStrengthStrong => 'Kuat. Mantap!';

  @override
  String get passwordTooShort => 'Pakai minimal 8 karakter.';

  @override
  String get registerButton => 'Daftar dan kirim kode';

  @override
  String get haveAccount => 'Sudah punya akun?';

  @override
  String get verifyTitle => 'Cek email kamu';

  @override
  String verifyBody(String email) {
    return 'Kami kirim 6 digit kode ke $email. Kode berlaku 15 menit.';
  }

  @override
  String get verifyCodeLabel => 'Kode verifikasi 6 digit';

  @override
  String get verifyButton => 'Verifikasi';

  @override
  String resendIn(String time) {
    return 'Kirim ulang kode dalam $time';
  }

  @override
  String get resendCode => 'Kirim ulang kode';

  @override
  String get codeResent => 'Kode baru sudah dikirim';

  @override
  String get checkSpam =>
      'Tidak ada di kotak masuk? Cek folder spam atau promosi.';

  @override
  String wrongCodeLeft(int count) {
    return 'Kode salah. Sisa $count percobaan.';
  }

  @override
  String get verifiedTitle => 'Email terverifikasi';

  @override
  String get verifiedBody => 'Akunmu siap. Lumi sudah menunggu.';

  @override
  String get startChatting => 'Mulai ngobrol';

  @override
  String get useAnotherAccount => 'Pakai akun lain';

  @override
  String get forgotTitle => 'Lupa password?';

  @override
  String get forgotBody =>
      'Tenang, tulis email akunmu. Kami kirim kode untuk membuat password baru.';

  @override
  String get sendCode => 'Kirim kode';

  @override
  String get sending => 'Mengirim…';

  @override
  String get resetTitle => 'Buat password baru';

  @override
  String get resetBody =>
      'Masukkan kode dari email, lalu password barunya. Setelah ini semua perangkat akan keluar.';

  @override
  String get codeLabel => 'Kode 6 digit';

  @override
  String get newPasswordLabel => 'Password baru';

  @override
  String get repeatPasswordLabel => 'Ulangi password baru';

  @override
  String get repeatPasswordHint => 'Ketik sekali lagi';

  @override
  String get passwordsDontMatch => 'Password tidak sama.';

  @override
  String get savePassword => 'Simpan password';

  @override
  String get passwordChangedTitle => 'Password diganti';

  @override
  String get passwordChangedBody =>
      'Demi keamanan, semua perangkat sudah dikeluarkan. Masuk lagi dengan password baru ya.';

  @override
  String get goToSignIn => 'Ke halaman Masuk';

  @override
  String stepOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get newChatTitle => 'Percakapan baru';

  @override
  String quotaLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sisa $count pesan hari ini',
      zero: 'Kuota hari ini habis',
    );
    return '$_temp0';
  }

  @override
  String get usingOwnKey => 'Pakai key AI kamu sendiri';

  @override
  String get messageHint => 'Tanya apa saja ke Lumi…';

  @override
  String get messageFieldLabel => 'Pesan untuk Lumi';

  @override
  String get send => 'Kirim';

  @override
  String get stopAnswer => 'Hentikan jawaban';

  @override
  String get stopped => 'Dihentikan';

  @override
  String get answerFailed => 'Lumi gagal menjawab.';

  @override
  String get typing => 'Lumi sedang mengetik';

  @override
  String get openHistory => 'Riwayat percakapan';

  @override
  String get openSettings => 'Pengaturan';

  @override
  String emptyChatTitle(String name) {
    return 'Halo $name! Ada yang bisa Lumi bantu?';
  }

  @override
  String get emptyChatBody =>
      'Tanya apa saja: rencana, resep, email, atau belajar hal baru.';

  @override
  String get suggestionTrip => 'Rencanakan liburan 3 hari';

  @override
  String get suggestionEmail => 'Tulis email yang sopan';

  @override
  String get suggestionExplain => 'Jelaskan dengan sederhana';

  @override
  String get suggestionTripPrompt =>
      'Bantu aku rencanakan liburan santai 3 hari.';

  @override
  String get suggestionEmailPrompt =>
      'Bantu aku tulis email sopan untuk minta izin cuti sehari.';

  @override
  String get suggestionExplainPrompt =>
      'Jelaskan cara kerja internet dengan sederhana.';

  @override
  String get chatGone => 'Percakapan ini dihapus dari perangkat lain.';

  @override
  String get copyCode => 'Salin';

  @override
  String get copied => 'Tersalin';

  @override
  String get historyTitle => 'Riwayat';

  @override
  String get newChatShort => 'Baru';

  @override
  String get searchChats => 'Cari percakapan';

  @override
  String get groupToday => 'Hari ini';

  @override
  String get groupYesterday => 'Kemarin';

  @override
  String get groupLast7 => '7 hari terakhir';

  @override
  String get groupOlder => 'Lebih lama';

  @override
  String get noResultsTitle => 'Tidak ketemu';

  @override
  String get noResultsBody => 'Coba kata lain dari judul atau isi percakapan.';

  @override
  String get noChatsTitle => 'Belum ada percakapan';

  @override
  String get noChatsBody =>
      'Mulai satu, nanti muncul di sini dan di semua perangkatmu.';

  @override
  String get deleteChatTitle => 'Hapus percakapan ini?';

  @override
  String deleteChatBody(String title) {
    return '“$title” akan hilang dari semua perangkatmu dan tidak bisa dikembalikan.';
  }

  @override
  String deleteChatA11y(String title) {
    return 'Hapus $title';
  }

  @override
  String get delete => 'Hapus';

  @override
  String get chatDeleted => 'Percakapan dihapus';

  @override
  String get newFromOtherDevice => 'Baru dari perangkat lain';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get verified => 'Terverifikasi';

  @override
  String quotaUsed(int used, int limit) {
    return '$used dari $limit pesan terpakai';
  }

  @override
  String get quotaNote =>
      'Kuota harian key Lumi. Reset tiap pukul 00.00 WIB. Pakai key sendiri untuk tanpa batas.';

  @override
  String get ownKeyNote =>
      'Key AI kamu sedang dipakai, jadi tidak ada batas harian.';

  @override
  String get myAiKey => 'Kunci AI saya';

  @override
  String get notSet => 'Belum diatur';

  @override
  String get statusOn => 'Aktif';

  @override
  String get statusOff => 'Nonaktif';

  @override
  String get activeDevices => 'Perangkat aktif';

  @override
  String get changePassword => 'Ganti password';

  @override
  String get language => 'Bahasa';

  @override
  String get languageFollowPhone => 'Ikuti HP';

  @override
  String get languageNote => 'Email dan pesan dari Lumi juga ikut bahasa ini.';

  @override
  String get signOut => 'Keluar';

  @override
  String get signOutTitle => 'Keluar dari Lumi?';

  @override
  String get signOutBody =>
      'Riwayat chat tetap aman di akunmu. Masuk lagi kapan saja.';

  @override
  String get changePasswordNote =>
      'Perangkat lain akan dikeluarkan. HP ini tetap masuk.';

  @override
  String get currentPasswordLabel => 'Password sekarang';

  @override
  String get passwordChangedToast => 'Password sudah diganti';

  @override
  String get aiKeyIntro =>
      'Pakai API key milikmu sendiri supaya chat tidak dibatasi kuota harian. Key disimpan terenkripsi di server dan tidak pernah ditampilkan lagi.';

  @override
  String get providerLabel => 'Provider';

  @override
  String get providerOther => 'Lainnya';

  @override
  String get providerOpenRouterHint =>
      'Banyak model gratis berlabel :free. Ambil key di openrouter.ai.';

  @override
  String get providerNimHint =>
      'Model gratis dari build.nvidia.com. Alamatnya sudah diisi Lumi.';

  @override
  String get providerOtherHint =>
      'Layanan lain yang kompatibel dengan API OpenAI.';

  @override
  String get baseUrlLabel => 'Base URL';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get apiKeyPaste => 'Tempel API key';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelHelp =>
      'Tulis ID model persis seperti di dashboard provider.';

  @override
  String get modelExampleFree => 'contoh: nama-model:free';

  @override
  String get modelExampleNim => 'contoh: vendor/nama-model';

  @override
  String get modelExampleOther => 'ID model dari provider';

  @override
  String get testAndSave => 'Uji dan simpan';

  @override
  String get replaceKey => 'Ganti key';

  @override
  String get replaceKeyNote =>
      'Isi formulir untuk mengganti key yang tersimpan.';

  @override
  String get testingKey => 'Menguji key…';

  @override
  String get keyWorks => 'Key berfungsi. Lumi sekarang pakai key kamu.';

  @override
  String get keyStillWorks => 'Key masih berfungsi.';

  @override
  String get testAgain => 'Uji ulang';

  @override
  String get removeKey => 'Hapus key';

  @override
  String get removeKeyTitle => 'Hapus key ini?';

  @override
  String removeKeyBody(int limit) {
    return 'Lumi kembali memakai key Lumi dengan kuota $limit pesan per hari.';
  }

  @override
  String get keyRemoved => 'Key dihapus';

  @override
  String keyStatusOn(String when) {
    return 'Aktif · diuji $when';
  }

  @override
  String get keyStatusOff => 'Nonaktif · pakai key Lumi';

  @override
  String keyLastError(String error) {
    return 'Uji terakhir gagal: $error';
  }

  @override
  String get useThisKey => 'Pakai key ini';

  @override
  String get devicesIntro =>
      'Akun Lumi kamu sedang masuk di perangkat ini. Keluarkan yang tidak kamu kenali, perangkat itu langsung kembali ke layar Masuk.';

  @override
  String get thisDevice => 'Perangkat ini';

  @override
  String get activeNow => 'Aktif sekarang';

  @override
  String get signOutDevice => 'Keluarkan';

  @override
  String signOutDeviceTitle(String name) {
    return 'Keluarkan $name?';
  }

  @override
  String signOutOthersTitle(int count) {
    return 'Keluarkan $count perangkat lain?';
  }

  @override
  String get signOutDeviceBody =>
      'Perangkat itu langsung keluar dan harus masuk lagi dengan password.';

  @override
  String get signOutAllOthers => 'Keluarkan semua perangkat lain';

  @override
  String get onlyThisDevice => 'Hanya perangkat ini yang masuk. Aman.';

  @override
  String devicesSignedOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count perangkat dikeluarkan',
      one: 'Perangkat dikeluarkan',
    );
    return '$_temp0';
  }

  @override
  String get timeJustNow => 'baru saja';

  @override
  String timeMinutesAgo(int count) {
    return '$count menit lalu';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count jam lalu';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count hari lalu';
  }

  @override
  String get sessionEndedTitle => 'Sesi berakhir';

  @override
  String get sessionEndedBody =>
      'Akunmu dikeluarkan dari perangkat ini, dari perangkat lain atau karena password diganti. Masuk lagi untuk lanjut.';

  @override
  String get signInAgain => 'Masuk lagi';

  @override
  String get quotaTitle => 'Kuota hari ini habis';

  @override
  String get quotaBody =>
      'Lumi istirahat dulu, kuota reset pukul 00.00 WIB. Pakai key AI sendiri supaya bisa lanjut tanpa batas.';

  @override
  String get setUpAiKey => 'Atur Kunci AI';

  @override
  String get catSleeping => 'Lumi si kucing tertidur';

  @override
  String get agentMenu => 'Agent';

  @override
  String get agentSubtitle =>
      'Atur karakter, memori, catatan, dan kemampuan Lumi.';

  @override
  String get agentPersona => 'Persona';

  @override
  String get agentMemory => 'Memori';

  @override
  String get agentNotes => 'Catatan';

  @override
  String get agentTools => 'Tools';

  @override
  String get comingSoon => 'Segera';

  @override
  String get personaTitle => 'Persona';

  @override
  String get personaSubtitle =>
      'Atur gaya bicara dan panggilan Lumi untukmu. Aturan keamanan inti tetap terjaga.';

  @override
  String get personaActiveLabel => 'Aktifkan persona';

  @override
  String get personaActiveHint =>
      'Matikan untuk memakai gaya netral bawaan Lumi.';

  @override
  String get personaPresetLabel => 'Preset gaya';

  @override
  String get personaCallMeLabel => 'Panggil saya';

  @override
  String get personaCallMeHint =>
      'Nama panggilan opsional (default: nama akunmu)';

  @override
  String get personaInstructionsLabel => 'Instruksi tambahan';

  @override
  String get personaInstructionsHint =>
      'contoh: Jelaskan langkah demi langkah, pakai contoh simpel, tanpa bahasa gaul…';

  @override
  String get personaGuardrailNote =>
      'Persona hanya mengatur gaya bicara, panggilan, dan nada — tidak pernah menimpa aturan keamanan atau izin tool Lumi.';

  @override
  String get personaSaved => 'Persona disimpan';

  @override
  String memorySubtitle(int limit) {
    return 'Fakta yang diingat Lumi antar percakapan. Maksimal $limit item; 20 terbaru otomatis masuk konteks.';
  }

  @override
  String get memorySearchHint => 'Cari memori';

  @override
  String get memoryAdd => 'Tambah memori';

  @override
  String get memoryEdit => 'Ubah memori';

  @override
  String get memoryContentLabel => 'Apa yang perlu Lumi ingat?';

  @override
  String get memoryContentHint =>
      'contoh: Lebih suka contoh kode Laravel yang ringkas';

  @override
  String get memoryCategoryLabel => 'Kategori';

  @override
  String get memoryCategoryFact => 'Fakta';

  @override
  String get memoryCategoryPreference => 'Preferensi';

  @override
  String get memoryCategoryContext => 'Konteks';

  @override
  String get memorySourceLumi => 'Lumi';

  @override
  String get memorySourceYou => 'Kamu';

  @override
  String get memoryEmptyTitle => 'Belum ada memori';

  @override
  String get memoryEmptyBody =>
      'Tambah preferensi atau fakta penting di sini supaya Lumi mengingatnya di tiap percakapan.';

  @override
  String get memoryDeleteTitle => 'Hapus memori ini?';

  @override
  String get memoryDeleteBody =>
      'Lumi akan melupakan catatan ini di semua perangkatmu.';

  @override
  String get memorySaved => 'Memori disimpan';

  @override
  String get memoryDeleted => 'Memori dihapus';

  @override
  String get notesSearchHint => 'Cari catatan';

  @override
  String get noteAdd => 'Catatan baru';

  @override
  String get noteEdit => 'Ubah catatan';

  @override
  String get noteTitleLabel => 'Judul';

  @override
  String get noteTitleHint => 'Judul singkat catatan';

  @override
  String get noteContentLabel => 'Isi';

  @override
  String get noteContentHint => 'Tulis apa saja yang ingin kamu simpan…';

  @override
  String get noteTagsLabel => 'Tag (opsional)';

  @override
  String get noteTagsHint => 'Pisahkan dengan koma, mis. kerja, ide';

  @override
  String get notesEmptyTitle => 'Belum ada catatan';

  @override
  String get notesEmptyBody =>
      'Simpan checklist, potongan kode, atau ide di sini agar mudah dicari kamu maupun Lumi.';

  @override
  String get noteDeleteTitle => 'Hapus catatan ini?';

  @override
  String noteDeleteBody(String title) {
    return '“$title” akan dihapus permanen.';
  }

  @override
  String get noteSaved => 'Catatan disimpan';

  @override
  String get noteDeleted => 'Catatan dihapus';

  @override
  String get serverButton => 'Server';

  @override
  String get serverTitle => 'Alamat server';

  @override
  String get serverSubtitle =>
      'Ubah alamat ini untuk tes lewat jaringan (mis. Cloudflare Tunnel) atau VPS Lumi Core milikmu.';

  @override
  String get serverUrlLabel => 'URL Lumi Core';

  @override
  String get serverBadgeDefault => 'Default';

  @override
  String get serverBadgeCustom => 'Custom';

  @override
  String get serverTestAndSave => 'Uji dan simpan';

  @override
  String get serverTesting => 'Mengecek server…';

  @override
  String get serverResetDefault => 'Kembali ke default';

  @override
  String get serverChangeLink => 'Ganti alamat server';

  @override
  String get serverUrlInvalid =>
      'Masukkan alamat http:// atau https:// yang valid.';

  @override
  String get serverCheckFailed =>
      'Alamat itu bukan server Lumi Core yang aktif.';

  @override
  String get serverSaved => 'Server diperbarui';

  @override
  String get serverResetToast => 'Kembali memakai server default';

  @override
  String get toolsSubtitle =>
      'Kemampuan yang bisa dipakai Lumi di akunmu. Aturan izin dijaga langsung oleh Lumi Core.';

  @override
  String get toolsEmpty => 'Belum ada tool yang aktif untuk akunmu.';

  @override
  String get toolModeAuto => 'Otomatis';

  @override
  String get toolModeAsk => 'Minta izin';

  @override
  String get aiKeySupportsTools => 'Model mendukung tools';

  @override
  String get actionApprovalBadge => 'Butuh persetujuan';

  @override
  String get actionApprove => 'Setujui';

  @override
  String get actionReject => 'Tolak';

  @override
  String get actionExpiryHint =>
      'Permintaan ini kedaluwarsa otomatis dalam 10 menit jika tidak dijawab.';

  @override
  String actionToolMeta(String tool) {
    return 'Tool: $tool';
  }

  @override
  String get networkInspectorTitle => 'Inspektor jaringan';

  @override
  String get networkInspectorSubtitle =>
      'Pantau traffic REST & SSE terbaru. Token, password, dan API key otomatis disamarkan.';

  @override
  String get networkInspectorFloating => 'Tombol mengambang';

  @override
  String get networkInspectorFloatingHint =>
      'Tampilkan tombol cepat HTTP di atas layar saat testing.';

  @override
  String get networkInspectorClear => 'Bersihkan';

  @override
  String get networkInspectorCleared => 'Log jaringan dibersihkan';

  @override
  String get networkInspectorEmpty => 'Belum ada request terekam';

  @override
  String get networkInspectorEmptyBody =>
      'Panggilan API dan stream chat akan muncul di sini otomatis.';

  @override
  String get networkInspectorFilterAll => 'Semua';

  @override
  String get networkInspectorFilterRest => 'REST';

  @override
  String get networkInspectorFilterSse => 'SSE';

  @override
  String get networkInspectorFilterErrors => 'Error';

  @override
  String get networkInspectorOverview => 'Ringkasan';

  @override
  String get networkInspectorRequest => 'Request';

  @override
  String get networkInspectorResponse => 'Response';

  @override
  String get networkInspectorCopyCurl => 'Salin cURL';

  @override
  String get networkInspectorCopyBody => 'Salin body';

  @override
  String get networkInspectorHeaders => 'Header';

  @override
  String get networkInspectorBody => 'Body';

  @override
  String get networkInspectorSseEvents => 'Event SSE';

  @override
  String get networkInspectorNoBody => 'Body kosong';
}
