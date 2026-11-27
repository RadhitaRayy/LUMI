import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../state/persona_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Per-user persona settings (Layer 4): preset picker, nickname, custom instructions & toggle.
class PersonaScreen extends ConsumerStatefulWidget {
  const PersonaScreen({super.key});

  @override
  ConsumerState<PersonaScreen> createState() => _PersonaScreenState();
}

class _PersonaScreenState extends ConsumerState<PersonaScreen> {
  static const _maxInstructions = 1000;
  static const _maxCallMe = 40;

  final _callMe = TextEditingController();
  final _instructions = TextEditingController();
  var _preset = 'santai';
  var _isActive = true;
  var _hydrated = false;
  var _saving = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    _instructions.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _callMe.dispose();
    _instructions.dispose();
    super.dispose();
  }

  void _hydrate(PersonaBundle? bundle) {
    if (_hydrated || bundle == null) return;
    _hydrated = true;
    _preset = bundle.persona.preset;
    _isActive = bundle.persona.isActive;
    _callMe.text = bundle.persona.callMe ?? '';
    _instructions.text = bundle.persona.customInstructions ?? '';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(personaProvider.notifier).save(
        preset: _preset,
        isActive: _isActive,
        callMe: _callMe.text,
        customInstructions: _instructions.text,
      );
      if (mounted) showToast(context, context.l10n.personaSaved);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? apiErrorText(context.l10n, e) : null;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(personaProvider);
    final bundle = async.value;
    _hydrate(bundle);

    return Scaffold(
      appBar: AppBar(title: Text(l.personaTitle), shape: const Border()),
      body: async.isLoading && bundle == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                FadeSlideIn(
                  child: Text(
                    l.personaSubtitle,
                    style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.muted),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn.step(
                  1,
                  child: Panel(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    borderColor: _isActive ? AppColors.accent.withValues(alpha: 0.35) : null,
                    child: Row(
                      children: [
                        const TintIcon(icon: Icons.auto_awesome_rounded, color: AppColors.accent, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.personaActiveLabel,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.personaActiveHint,
                                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedOpacity(
                  duration: Motion.of(context, const Duration(milliseconds: 200)),
                  opacity: _isActive ? 1 : 0.45,
                  child: IgnorePointer(
                    ignoring: !_isActive,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeSlideIn.step(
                          2,
                          child: LabeledField(
                            label: l.personaPresetLabel,
                            child: Column(
                              children: [
                                for (final preset in bundle?.presets ?? const <PersonaPreset>[])
                                  _PresetCard(
                                    preset: preset,
                                    selected: _preset == preset.id,
                                    onTap: () => setState(() => _preset = preset.id),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeSlideIn.step(
                          3,
                          child: LabeledField(
                            label: l.personaCallMeLabel,
                            child: TextField(
                              controller: _callMe,
                              maxLength: _maxCallMe,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                hintText: l.personaCallMeHint,
                                counterText: '',
                                errorText: _fieldErrors['call_me']?.first,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeSlideIn.step(
                          4,
                          child: LabeledField(
                            label: l.personaInstructionsLabel,
                            trailing: Text(
                              '${_instructions.text.length}/$_maxInstructions',
                              style: AppText.mono(12, color: AppColors.muted),
                            ),
                            child: TextField(
                              controller: _instructions,
                              minLines: 4,
                              maxLines: 7,
                              maxLength: _maxInstructions,
                              decoration: InputDecoration(
                                hintText: l.personaInstructionsHint,
                                counterText: '',
                                errorText: _fieldErrors['custom_instructions']?.first,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l.personaGuardrailNote,
                          style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.faint),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger)),
                ],
                const SizedBox(height: 22),
                FadeSlideIn.step(
                  5,
                  child: PrimaryButton(label: l.save, loading: _saving, onPressed: _save),
                ),
              ],
            ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.selected, required this.onTap});

  final PersonaPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, const Duration(milliseconds: 200)),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.1) : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(preset.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          preset.description,
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: Motion.of(context, const Duration(milliseconds: 200)),
                    curve: Motion.pop,
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
