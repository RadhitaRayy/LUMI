import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/models.dart';
import 'core_providers.dart';
import 'locale_controller.dart';
import 'session_controller.dart';

/// User's Lumi persona (preset, nickname, custom instructions, on/off), synced via Core.
class PersonaController extends AsyncNotifier<PersonaBundle> {
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<PersonaBundle> build() async {
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    ref.watch(localeProvider.select((s) => s.code));
    if (userId == null) {
      return const PersonaBundle(
        persona: UserPersona(preset: 'santai', isActive: true),
        presets: [],
      );
    }
    final body = await _api.get('me/persona');
    return PersonaBundle.fromJson(body);
  }

  Future<void> save({
    required String preset,
    required bool isActive,
    String? callMe,
    String? customInstructions,
  }) async {
    final body = await _api.put('me/persona', {
      'preset': preset,
      'call_me': (callMe ?? '').trim().isEmpty ? null : callMe!.trim(),
      'custom_instructions': (customInstructions ?? '').trim().isEmpty ? null : customInstructions!.trim(),
      'is_active': isActive,
    });
    state = AsyncData(PersonaBundle.fromJson(body));
  }

  /// Synced from another device (`persona.updated` Reverb event).
  void applyRemote(Map<String, dynamic> raw) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(PersonaBundle(persona: UserPersona.fromJson(raw), presets: current.presets));
  }
}

final personaProvider = AsyncNotifierProvider<PersonaController, PersonaBundle>(PersonaController.new);
