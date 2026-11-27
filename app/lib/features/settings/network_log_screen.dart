import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/http_log.dart';
import '../../state/core_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../widgets/ui.dart';

enum _LogFilter { all, rest, sse, errors }

/// Chucker-style built-in HTTP & SSE network inspector for testing Lumi Core traffic.
class NetworkLogScreen extends ConsumerStatefulWidget {
  const NetworkLogScreen({super.key});

  /// Prevents the floating inspector button from pushing duplicate copies.
  static var isOpen = false;

  @override
  ConsumerState<NetworkLogScreen> createState() => _NetworkLogScreenState();
}

class _NetworkLogScreenState extends ConsumerState<NetworkLogScreen> {
  _LogFilter _filter = _LogFilter.all;

  @override
  void initState() {
    super.initState();
    NetworkLogScreen.isOpen = true;
  }

  @override
  void dispose() {
    NetworkLogScreen.isOpen = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final store = ref.watch(httpLogStoreProvider);
    final overlayEnabled = ref.watch(inspectorOverlayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.networkInspectorTitle),
        actions: [
          IconButton(
            tooltip: l.networkInspectorClear,
            onPressed: () {
              store.clear();
              showToast(context, l.networkInspectorCleared);
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final filtered = store.entries.where((e) {
            return switch (_filter) {
              _LogFilter.all => true,
              _LogFilter.rest => !e.isSse,
              _LogFilter.sse => e.isSse,
              _LogFilter.errors => e.isError,
            };
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Panel(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.networkInspectorSubtitle,
                        style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.networkInspectorFloating,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  l.networkInspectorFloatingHint,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: overlayEnabled,
                            onChanged: (v) => ref.read(inspectorOverlayProvider.notifier).setEnabled(v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (value, label) in [
                      (_LogFilter.all, l.networkInspectorFilterAll),
                      (_LogFilter.rest, l.networkInspectorFilterRest),
                      (_LogFilter.sse, l.networkInspectorFilterSse),
                      (_LogFilter.errors, l.networkInspectorFilterErrors),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _filter == value,
                          label: Text(label),
                          onSelected: (_) => setState(() => _filter = value),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const TintIcon(icon: Icons.wifi_tethering_rounded, color: AppColors.info, size: 52),
                              const SizedBox(height: 12),
                              Text(l.networkInspectorEmpty, style: AppText.heading(17)),
                              const SizedBox(height: 6),
                              Text(
                                l.networkInspectorEmptyBody,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          return _LogTile(
                            entry: entry,
                            onTap: () => Navigator.of(context).push(
                              lumiRoute<void>(_NetworkLogDetailScreen(entryId: entry.id)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.onTap});

  final HttpLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _statusColor(entry);
    final statusLabel = entry.error != null && entry.statusCode == null
        ? 'ERR'
        : entry.statusCode == null
        ? '…'
        : '${entry.statusCode}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: entry.isError ? AppColors.danger.withValues(alpha: 0.4) : AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  textAlign: TextAlign.center,
                  style: AppText.mono(12, weight: FontWeight.w700, color: badgeColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.method,
                          style: AppText.mono(12, weight: FontWeight.w700, color: AppColors.accent),
                        ),
                        if (entry.isSse) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SSE',
                              style: AppText.mono(10, weight: FontWeight.w700, color: AppColors.info),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatClock(entry.startedAt),
                          style: AppText.mono(11, color: AppColors.faint),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.mono(13, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.durationMs != null)
                          Text(
                            '${entry.durationMs} ms',
                            style: AppText.mono(11, color: AppColors.muted),
                          ),
                        if (entry.isSse && entry.sseEvents.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Text(
                            '${entry.sseEvents.length} events',
                            style: AppText.mono(11, color: AppColors.info),
                          ),
                        ],
                        if (entry.error != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              entry.error!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppColors.danger),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetworkLogDetailScreen extends ConsumerWidget {
  const _NetworkLogDetailScreen({required this.entryId});

  final int entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final store = ref.watch(httpLogStoreProvider);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final entry = store.entries.where((e) => e.id == entryId).firstOrNull;
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l.networkInspectorTitle)),
            body: Center(child: Text(l.networkInspectorEmpty)),
          );
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: Text('${entry.method} ${entry.statusCode ?? ''}'),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.toCurl()));
                    showToast(context, l.copied);
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(l.networkInspectorCopyCurl),
                ),
              ],
              bottom: TabBar(
                tabs: [
                  Tab(text: l.networkInspectorOverview),
                  Tab(text: l.networkInspectorRequest),
                  Tab(text: l.networkInspectorResponse),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OverviewTab(entry: entry),
                _PayloadTab(
                  headers: entry.requestHeaders,
                  body: entry.requestBody,
                ),
                _ResponseTab(entry: entry),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.entry});

  final HttpLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('URL', entry.url),
              _kv('Method', entry.method),
              _kv('Protocol', entry.isSse ? 'HTTP + SSE Stream' : 'HTTP JSON'),
              _kv('Status', entry.statusCode != null ? '${entry.statusCode}' : (entry.error ?? 'Pending')),
              _kv('Latency', entry.durationMs != null ? '${entry.durationMs} ms' : '—'),
              _kv('Started', _formatClock(entry.startedAt)),
              if (entry.error != null) _kv('Error', entry.error!, color: AppColors.danger),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          SelectableText(v, style: AppText.mono(13, color: color ?? AppColors.text)),
        ],
      ),
    );
  }
}

class _PayloadTab extends StatelessWidget {
  const _PayloadTab({required this.headers, this.body});

  final Map<String, String> headers;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(label: l.networkInspectorHeaders),
        const SizedBox(height: 6),
        _CodeBlock(
          text: headers.isEmpty
              ? '—'
              : headers.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _SectionTitle(label: l.networkInspectorBody),
            const Spacer(),
            if (body != null && body!.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: body!));
                  showToast(context, l.copied);
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(l.networkInspectorCopyBody),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _CodeBlock(text: (body?.isNotEmpty ?? false) ? body! : l.networkInspectorNoBody),
      ],
    );
  }
}

class _ResponseTab extends StatelessWidget {
  const _ResponseTab({required this.entry});

  final HttpLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final body = entry.isSse && entry.sseEvents.isNotEmpty
        ? entry.sseEvents.join('\n')
        : entry.responseBody;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle(label: l.networkInspectorHeaders),
        const SizedBox(height: 6),
        _CodeBlock(
          text: entry.responseHeaders.isEmpty
              ? '—'
              : entry.responseHeaders.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _SectionTitle(label: entry.isSse ? l.networkInspectorSseEvents : l.networkInspectorBody),
            const Spacer(),
            if (body != null && body.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: body));
                  showToast(context, l.copied);
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: Text(l.networkInspectorCopyBody),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _CodeBlock(text: (body?.isNotEmpty ?? false) ? body! : l.networkInspectorNoBody),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SelectableText(
        text,
        style: AppText.mono(12, color: AppColors.text),
      ),
    );
  }
}

Color _statusColor(HttpLogEntry entry) {
  if (entry.isError) return AppColors.danger;
  if (entry.statusCode == null) return AppColors.warn;
  if (entry.statusCode! >= 200 && entry.statusCode! < 300) return AppColors.accent;
  return AppColors.info;
}

String _formatClock(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}
