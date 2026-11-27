import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../state/server_url_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Opens a bottom sheet to test and switch the Lumi Core server address (e.g. tunnel or self-hosted VPS).
Future<bool> showServerSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: const AnimationStyle(duration: Motion.sheet),
    builder: (_) => const _ServerSheet(),
  );
  return changed ?? false;
}

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final _url = TextEditingController(text: ref.read(serverUrlProvider).effectiveUrl);
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(serverUrlProvider.notifier).testAndSave(_url.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showToast(context, context.l10n.serverSaved);
    } on ApiException catch (e) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _error = switch (e.code) {
          'server_url_invalid' => l.serverUrlInvalid,
          'server_invalid' => l.serverCheckFailed,
          _ => apiErrorText(l, e),
        };
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await ref.read(serverUrlProvider.notifier).reset();
    if (!mounted) return;
    Navigator.of(context).pop(true);
    showToast(context, context.l10n.serverResetToast);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(serverUrlProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.serverTitle, style: AppText.heading(20))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: state.isCustom ? AppColors.accent.withValues(alpha: 0.12) : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    state.isCustom ? l.serverBadgeCustom : l.serverBadgeDefault,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: state.isCustom ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(l.serverSubtitle, style: const TextStyle(fontSize: 13, height: 1.45, color: AppColors.muted)),
            const SizedBox(height: 14),
            LabeledField(
              label: l.serverUrlLabel,
              child: TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                style: AppText.mono(14),
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  hintText: 'https://your-lumi-server.example.com',
                  fillColor: AppColors.bg,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.danger, height: 1.4)),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: _busy ? l.serverTesting : l.serverTestAndSave,
              loading: _busy,
              onPressed: _save,
            ),
            if (state.isCustom) ...[
              const SizedBox(height: 10),
              SecondaryButton(label: l.serverResetDefault, onPressed: _busy ? null : _reset),
            ],
          ],
        ),
      ),
    );
  }
}
