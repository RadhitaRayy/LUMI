import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Languages the app ships. Adding one = a new `lib/l10n/app_xx.arb` + an entry here
/// (and in Core's `supported_locales`).
const supportedLanguages = <String, String>{'id': 'Bahasa Indonesia', 'en': 'English'};

class LocaleState {
  const LocaleState({required this.choice, required this.systemCode});

  /// What the user picked; `null` follows the phone.
  final String? choice;
  final String systemCode;

  /// The language actually used. Phones in an unsupported language get English.
  String get code => choice ?? (supportedLanguages.containsKey(systemCode) ? systemCode : 'en');

  Locale get locale => Locale(code);
}

class LocaleController extends Notifier<LocaleState> {
  @override
  LocaleState build() {
    final state = LocaleState(choice: null, systemCode: _systemCode());
    ref.read(apiClientProvider).locale = state.code;
    return state;
  }

  static String _systemCode() =>
      PlatformDispatcher.instance.locale.languageCode.toLowerCase();

  Future<void> load() async {
    final saved = await ref.read(storageProvider).readLocale();
    _set(LocaleState(
      choice: supportedLanguages.containsKey(saved) ? saved : null,
      systemCode: _systemCode(),
    ));
  }

  /// The phone's language changed while the app was open.
  void systemChanged() {
    if (state.systemCode != _systemCode()) {
      _set(LocaleState(choice: state.choice, systemCode: _systemCode()));
    }
  }

  Future<void> choose(String? code) async {
    await ref.read(storageProvider).saveLocale(code);
    _set(LocaleState(choice: code, systemCode: _systemCode()));
  }

  void _set(LocaleState next) {
    state = next;
    ref.read(apiClientProvider).locale = next.code;
  }
}

final localeProvider = NotifierProvider<LocaleController, LocaleState>(LocaleController.new);
