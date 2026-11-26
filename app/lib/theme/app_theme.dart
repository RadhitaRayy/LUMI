import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet warna Lumi — mode gelap ala terminal.
abstract final class AppColors {
  static const bg = Color(0xFF0E1014);
  static const surface = Color(0xFF171A20);
  static const surfaceHigh = Color(0xFF1F232B);
  static const card = Color(0xFF13161B);
  static const border = Color(0xFF2A2F38);
  static const divider = Color(0xFF1F232B);
  static const handle = Color(0xFF3A404B);
  static const text = Color(0xFFECEEF1);
  static const muted = Color(0xFF9BA3AF);

  /// Aksi berhasil / tombol utama.
  static const accent = Color(0xFFB5F23D);

  /// Aksi yang butuh izin.
  static const warn = Color(0xFFF5B544);

  /// Aksi yang menghapus atau mengeluarkan.
  static const danger = Color(0xFFFFA899);
  static const info = Color(0xFF8FB4FF);
  static const labelText = Color(0xFFC9CED6);
  static const faint = Color(0xFF8A93A0);
  static const line = Color(0xFF23272F);
  static const lamp = Color(0xFF3A4150);
}

/// Matikan di test supaya google_fonts tidak mencoba fetch dari internet.
abstract final class AppFonts {
  static bool useGoogleFonts = true;
}

TextStyle _font(String family, TextStyle style) => AppFonts.useGoogleFonts
    ? GoogleFonts.getFont(family, textStyle: style)
    : style.copyWith(fontFamily: family);

abstract final class AppText {
  static TextStyle heading(
    double size, {
    FontWeight weight = FontWeight.w600,
  }) => _font(
    'Space Grotesk',
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: AppColors.text,
      height: 1.2,
    ),
  );

  static TextStyle mono(
    double size, {
    Color color = AppColors.text,
    FontWeight weight = FontWeight.w400,
  }) => _font(
    'JetBrains Mono',
    TextStyle(fontSize: size, color: color, fontWeight: weight),
  );

  /// The `lumi` wordmark: Bricolage Grotesque 800, tight letter spacing.
  static TextStyle logo(double size, {Color color = AppColors.text}) => _font(
    'Bricolage Grotesque',
    TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: size * -0.05,
      height: 1,
      color: color,
    ),
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
  );

  static const sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.7,
    color: AppColors.muted,
  );
}

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  final baseText = AppFonts.useGoogleFonts
      ? GoogleFonts.interTextTheme(base.textTheme)
      : base.textTheme;
  final textTheme = baseText.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );

  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color),
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.bg,
      secondary: AppColors.warn,
      onSecondary: AppColors.bg,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.border,
      error: Color(0xFFFF8A80),
    ),
    textTheme: textTheme,
    dividerColor: AppColors.divider,
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.heading(18),
      shape: const Border(bottom: BorderSide(color: AppColors.divider)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.accent),
      errorBorder: border(const Color(0xFFFF8A80)),
      focusedErrorBorder: border(const Color(0xFFFF8A80)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(64, 52),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        minimumSize: const Size(44, 44),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(AppColors.bg),
      side: const BorderSide(color: AppColors.muted, width: 1.5),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? AppColors.bg : AppColors.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.accent
            : AppColors.surfaceHigh,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
      showDragHandle: true,
      dragHandleColor: AppColors.handle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
