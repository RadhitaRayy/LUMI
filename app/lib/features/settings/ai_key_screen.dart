import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../state/account_controllers.dart';
import '../../state/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// "My AI key": pick a provider (the highlight slides), paste a key, test it, then a status card flips in.
class AiKeyScreen extends ConsumerStatefulWidget {
  const AiKeyScreen({super.key});

  @override
  ConsumerState<AiKeyScreen> createState() => _AiKeyScreenState();
}

class _AiKeyScreenState extends ConsumerState<AiKeyScreen> with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _baseUrl = TextEditingController();
  final _key = TextEditingController();
  final _model = TextEditingController();
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
  var _provider = AiProvider.openRouter;
  var _busy = false;
  var _testing = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};
  var _prefilled = false;

  @override
  void dispose() {
    _baseUrl.dispose();
    _key.dispose();
    _model.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _prefill(AiKey? key) {
    if (_prefilled || key == null) return;
    _prefilled = true;
    _provider = key.provider;
    _model.text = key.modelId;
    if (key.provider == AiProvider.other) _baseUrl.text = key.baseUrl ?? '';
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await ref.read(aiKeyProvider.notifier).save(
        provider: _provider,
        apiKey: _key.text,
        modelId: _model.text,
        baseUrl: _baseUrl.text,
      );
      _key.clear();
      if (mounted) showToast(context, context.l10n.keyWorks);
    } on ApiException catch (e) {
      if (!mounted) return;
      _shake.forward(from: 0);
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? apiErrorText(context.l10n, e) : null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await ref.read(aiKeyProvider.notifier).test();
      if (mounted) showToast(context, context.l10n.keyStillWorks);
    } on ApiException catch (e) {
      ref.invalidate(aiKeyProvider);
      if (mounted) showToast(context, apiErrorText(context.l10n, e), success: false);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _toggle(bool active) async {
    try {
      await ref.read(aiKeyProvider.notifier).setActive(active);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(context.l10n, e), success: false);
    }
  }

  Future<void> _toggleTools(bool supports) async {
    try {
      await ref.read(aiKeyProvider.notifier).setSupportsTools(supports);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(context.l10n, e), success: false);
    }
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final limit = ref.read(sessionProvider).user?.quota.dailyLimit ?? 0;
    final ok = await confirmSheet(context, title: l.removeKeyTitle, body: l.removeKeyBody(limit), confirmLabel: l.removeKey);
    if (!ok) return;
    try {
      await ref.read(aiKeyProvider.notifier).remove();
      if (mounted) showToast(context, l.keyRemoved);
    } on ApiException catch (e) {
      if (mounted) showToast(context, apiErrorText(l, e), success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(aiKeyProvider);
    final saved = async.value;
    _prefill(saved);

    final hints = {
      AiProvider.openRouter: (l.providerOpenRouterHint, 'sk-or-v1-…', l.modelExampleFree),
      AiProvider.nim: (l.providerNimHint, 'nvapi-…', l.modelExampleNim),
      AiProvider.other: (l.providerOtherHint, l.apiKeyPaste, l.modelExampleOther),
    };
    final (hint, keyHint, modelHint) = hints[_provider]!;

    return Scaffold(
      appBar: AppBar(title: Text(l.myAiKey), shape: const Border()),
      body: async.isLoading && saved == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  AnimatedSwitcher(
                    duration: Motion.of(context, const Duration(milliseconds: 450)),
                    transitionBuilder: (child, animation) => AnimatedBuilder(
                      animation: animation,
                      builder: (_, c) => Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0015)
                          ..rotateX((1 - animation.value) * -math.pi / 2.6),
                        child: Opacity(opacity: animation.value, child: c),
                      ),
                      child: child,
                    ),
                    child: saved == null
                        ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                        : Padding(
                            key: ValueKey('${saved.keyLast4}-${saved.isActive}-${saved.supportsTools}'),
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _StatusCard(
                              keyInfo: saved,
                              testing: _testing,
                              onTest: _test,
                              onToggle: _toggle,
                              onToggleTools: _toggleTools,
                              onRemove: _remove,
                            ),
                          ),
                  ),
                  FadeSlideIn(
                    child: Text(
                      saved == null ? l.aiKeyIntro : l.replaceKeyNote,
                      style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeSlideIn.step(
                    1,
                    child: LabeledField(
                      label: l.providerLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProviderPicker(
                            value: _provider,
                            labels: {AiProvider.openRouter: 'OpenRouter', AiProvider.nim: 'NVIDIA NIM', AiProvider.other: l.providerOther},
                            onChanged: (p) => setState(() {
                              _provider = p;
                              _error = null;
                            }),
                          ),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: Motion.of(context, const Duration(milliseconds: 200)),
                            child: Text(hint, key: ValueKey(hint), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: Motion.of(context, const Duration(milliseconds: 300)),
                    curve: Motion.ease,
                    child: _provider == AiProvider.other
                        ? Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: LabeledField(
                              label: l.baseUrlLabel,
                              child: TextFormField(
                                controller: _baseUrl,
                                keyboardType: TextInputType.url,
                                style: AppText.mono(14),
                                decoration: InputDecoration(
                                  hintText: 'https://api.example.com/v1',
                                  errorText: _fieldErrors['base_url']?.first,
                                ),
                                validator: (v) => _provider == AiProvider.other && (v ?? '').trim().isEmpty ? l.fieldRequired : null,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn.step(
                    2,
                    child: AnimatedBuilder(
                      animation: _shake,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(math.sin(_shake.value * math.pi * 4) * 8 * (1 - _shake.value), 0),
                        child: child,
                      ),
                      child: LabeledField(
                        label: l.apiKeyLabel,
                        child: TextFormField(
                          controller: _key,
                          obscureText: true,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: AppText.mono(14),
                          decoration: InputDecoration(hintText: keyHint, errorText: _fieldErrors['api_key']?.first),
                          validator: (v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn.step(
                    3,
                    child: LabeledField(
                      label: l.modelLabel,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _model,
                            autocorrect: false,
                            style: AppText.mono(14),
                            decoration: InputDecoration(hintText: modelHint, errorText: _fieldErrors['model_id']?.first),
                            validator: (v) => (v ?? '').trim().isEmpty ? l.fieldRequired : null,
                          ),
                          const SizedBox(height: 8),
                          Text(l.modelHelp, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.4)),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FadeSlideIn.step(
                    4,
                    child: PrimaryButton(
                      label: _busy ? l.testingKey : (saved == null ? l.testAndSave : l.replaceKey),
                      loading: _busy,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProviderPicker extends StatelessWidget {
  const _ProviderPicker({required this.value, required this.labels, required this.onChanged});

  final AiProvider value;
  final Map<AiProvider, String> labels;
  final ValueChanged<AiProvider> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = AiProvider.values;
    final index = options.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: Motion.of(context, const Duration(milliseconds: 300)),
              curve: const Cubic(0.3, 1.2, 0.5, 1),
              alignment: Alignment(-1 + index * 1.0, 0),
              child: FractionallySizedBox(
                widthFactor: 1 / options.length,
                heightFactor: 1,
                child: Container(
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final option in options)
                Expanded(
                  child: Semantics(
                    selected: option == value,
                    inMutuallyExclusiveGroup: true,
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onChanged(option),
                      child: SizedBox(
                        height: 44,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.of(context, const Duration(milliseconds: 200)),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: option == value ? AppColors.text : AppColors.muted,
                            ),
                            child: Text(labels[option]!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.keyInfo,
    required this.testing,
    required this.onTest,
    required this.onToggle,
    required this.onToggleTools,
    required this.onRemove,
  });

  final AiKey keyInfo;
  final bool testing;
  final VoidCallback onTest;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onToggleTools;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final provider = switch (keyInfo.provider) {
      AiProvider.openRouter => 'OpenRouter',
      AiProvider.nim => 'NVIDIA NIM',
      AiProvider.other => l.providerOther,
    };
    final status = keyInfo.isActive ? l.keyStatusOn(relativeTime(l, keyInfo.lastValidatedAt)) : l.keyStatusOff;

    return Panel(
      padding: const EdgeInsets.all(18),
      borderColor: keyInfo.isActive ? AppColors.accent.withValues(alpha: 0.35) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const TintIcon(icon: Icons.key_rounded, color: AppColors.accent, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$provider ', style: const TextStyle(fontWeight: FontWeight.w600)),
                          TextSpan(text: '••••${keyInfo.keyLast4}', style: AppText.mono(14, color: AppColors.muted)),
                        ],
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(keyInfo.modelId, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.mono(12, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(status, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Semantics(label: l.useThisKey, child: Switch(value: keyInfo.isActive, onChanged: onToggle)),
            ],
          ),
          if (keyInfo.lastError != null) ...[
            const SizedBox(height: 10),
            Text(l.keyLastError(keyInfo.lastError!), style: const TextStyle(fontSize: 12, color: AppColors.danger, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(l.aiKeySupportsTools, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              ),
              Semantics(
                label: l.aiKeySupportsTools,
                child: Switch(value: keyInfo.supportsTools, onChanged: onToggleTools),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: testing ? null : onTest,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.transparent, minimumSize: const Size(0, 44)),
                    onPressed: testing ? null : onTest,
                    child: testing
                        ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.testAgain),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Pressable(
                  onTap: onRemove,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: onRemove,
                    child: Text(l.removeKey),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
