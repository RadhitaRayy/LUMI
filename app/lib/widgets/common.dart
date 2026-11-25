import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../theme/app_theme.dart';

/// Titik status kecil (online = hijau lime).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, this.color = AppColors.accent, this.size = 6});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Label izin tool: Otomatis (lime) atau Minta izin (amber).
class PermissionBadge extends StatelessWidget {
  const PermissionBadge(this.mode, {super.key});

  final PermissionMode mode;

  @override
  Widget build(BuildContext context) {
    final color = mode == PermissionMode.auto
        ? AppColors.accent
        : AppColors.warn;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        mode.label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Logo Lumi: prompt terminal di kotak lime.
class LumiLogo extends StatelessWidget {
  const LumiLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      child: Icon(
        Icons.terminal_rounded,
        color: AppColors.bg,
        size: size * 0.52,
      ),
    );
  }
}

/// Judul section kecil berhuruf kapital.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppText.sectionLabel);
  }
}

/// Kartu bergaris tepi untuk mengelompokkan baris.
class OutlinedCard extends StatelessWidget {
  const OutlinedCard({
    super.key,
    required this.child,
    this.color = AppColors.surface,
    this.radius = 16,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

void showDemoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
