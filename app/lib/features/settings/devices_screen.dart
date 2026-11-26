import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../data/models.dart';
import '../../state/account_controllers.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

/// Devices signed in to this account. Signing one out collapses its row and shows a toast.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _leaving = <int>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(devicesProvider));
  }

  Future<void> _signOut(List<Device> devices) async {
    final l = context.l10n;
    final ok = await confirmSheet(
      context,
      title: devices.length == 1 ? l.signOutDeviceTitle(devices.single.name) : l.signOutOthersTitle(devices.length),
      body: l.signOutDeviceBody,
      confirmLabel: l.signOutDevice,
    );
    if (!ok || !mounted) return;
    final ids = devices.map((d) => d.id).toList();
    setState(() => _leaving.addAll(ids));
    try {
      await Future.wait([
        ref.read(devicesProvider.notifier).signOut(ids),
        Future<void>.delayed(Motion.of(context, const Duration(milliseconds: 300))),
      ]);
      if (mounted) showToast(context, l.devicesSignedOut(ids.length));
    } on ApiException catch (e) {
      ref.invalidate(devicesProvider);
      if (mounted) showToast(context, apiErrorText(l, e), success: false);
    } finally {
      if (mounted) setState(() => _leaving.removeAll(ids));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(devicesProvider);
    final devices = async.value ?? const <Device>[];
    final others = devices.where((d) => !d.isCurrent).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l.activeDevices), shape: const Border()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeSlideIn(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(l.devicesIntro, style: const TextStyle(fontSize: 14, height: 1.55, color: AppColors.muted)),
            ),
          ),
          const SizedBox(height: 16),
          if (async.isLoading && async.value == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
          else if (async.hasError && async.value == null)
            Text(apiErrorText(l, async.error!), style: const TextStyle(color: AppColors.danger))
          else
            FadeSlideIn.step(
              1,
              child: Panel(
                child: Column(
                  children: [
                    for (final (i, device) in devices.indexed)
                      _DeviceRow(
                        key: ValueKey(device.id),
                        device: device,
                        divider: i > 0,
                        leaving: _leaving.contains(device.id),
                        onSignOut: () => _signOut([device]),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 250)),
            child: async.value == null
                ? const SizedBox.shrink()
                : others.isNotEmpty
                ? FadeSlideIn.step(
                    2,
                    key: const ValueKey('all'),
                    child: SecondaryButton(label: l.signOutAllOthers, danger: true, onPressed: () => _signOut(others)),
                  )
                : Padding(
                    key: const ValueKey('alone'),
                    padding: const EdgeInsets.all(8),
                    child: Text(l.onlyThisDevice, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    super.key,
    required this.device,
    required this.divider,
    required this.leaving,
    required this.onSignOut,
  });

  final Device device;
  final bool divider;
  final bool leaving;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final duration = Motion.of(context, const Duration(milliseconds: 300));
    final recent = device.lastUsedAt != null && DateTime.now().difference(device.lastUsedAt!).inMinutes < 5;

    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOut,
      child: leaving
          ? const SizedBox(width: double.infinity)
          : Container(
              decoration: BoxDecoration(
                border: divider ? const Border(top: BorderSide(color: AppColors.divider)) : null,
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  TintIcon(
                    icon: device.looksLikeTablet ? Icons.tablet_mac_rounded : Icons.smartphone_rounded,
                    color: device.isCurrent ? AppColors.accent : AppColors.labelText,
                    size: 42,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(device.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            if (device.isCurrent)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  l.thisDevice,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (device.isCurrent || recent) ...[const PulsingDot(size: 7), const SizedBox(width: 6)],
                            Text(
                              device.isCurrent || recent ? l.activeNow : relativeTime(l, device.lastUsedAt),
                              style: const TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!device.isCurrent)
                    Pressable(
                      onTap: onSignOut,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        onPressed: onSignOut,
                        child: Text(l.signOutDevice),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
