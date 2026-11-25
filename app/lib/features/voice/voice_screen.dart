import 'dart:async';
import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

/// Mode suara. Versi demo mensimulasikan transkrip; nanti pakai
/// package speech_to_text.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen>
    with SingleTickerProviderStateMixin {
  static const _demoWords = [
    'cek', 'log', 'error', 'bot', 'discord', 'dari', 'tadi', 'pagi', //
  ];

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  Timer? _timer;
  int _shown = 0;

  bool get _done => _shown >= _demoWords.length;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    _timer?.cancel();
    setState(() => _shown = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 380), (t) {
      if (_done) {
        t.cancel();
        return;
      }
      setState(() => _shown++);
    });
  }

  String get _transcript => _demoWords.take(_shown).join(' ');

  void _finish() {
    Navigator.of(context).pop(_transcript);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final words = _demoWords.take(_shown).toList();
    final settled = words.length > 3
        ? words.sublist(0, words.length - 3)
        : <String>[];
    final live = words.length > 3 ? words.sublist(words.length - 3) : words;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        shape: const Border(),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Tutup mode suara',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Mode suara',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'ID',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Orb(animation: _wave, active: !_done),
                    const SizedBox(height: 36),
                    Text(
                      _done ? 'SELESAI · KETUK KIRIM' : 'MENDENGARKAN…',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 72,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: settled.join(' ')),
                            if (settled.isNotEmpty) const TextSpan(text: ' '),
                            TextSpan(
                              text: live.join(' '),
                              style: TextStyle(
                                color: _done ? AppColors.text : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppText.heading(27, weight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_shown >= 2)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.terminal_rounded,
                              size: 14,
                              color: AppColors.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'akan memakai: ',
                              style: AppText.mono(12, color: AppColors.muted),
                            ),
                            Text('baca_log', style: AppText.mono(12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundButton(
                    tooltip: 'Ganti ke ketik',
                    icon: Icons.keyboard_alt_outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: IconButton.filled(
                      tooltip: _done ? 'Kirim' : 'Selesai bicara',
                      style: IconButton.styleFrom(
                        backgroundColor: _done
                            ? AppColors.accent
                            : AppColors.text,
                        foregroundColor: AppColors.bg,
                      ),
                      iconSize: 30,
                      icon: Icon(
                        _done ? Icons.arrow_upward_rounded : Icons.stop_rounded,
                      ),
                      onPressed: _finish,
                    ),
                  ),
                  _RoundButton(
                    tooltip: 'Ulangi',
                    icon: Icons.refresh_rounded,
                    onPressed: _startListening,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: IconButton.outlined(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
        ),
        icon: Icon(icon),
        onPressed: onPressed,
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.animation, required this.active});

  final Animation<double> animation;
  final bool active;

  static const _base = [18.0, 38.0, 54.0, 30.0, 14.0];

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 240,
        height: 240,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value * 2 * pi;
            final pulse = active ? 1 + 0.04 * sin(t) : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 186,
                  height: 186,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.06),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                Container(
                  width: 128,
                  height: 128,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _base.length; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: active
                              ? _base[i] *
                                    (0.55 + 0.45 * sin(t + i * 0.9).abs())
                              : 6,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
