import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/motion.dart';

/// Lumi, the orange cat with a lime lantern, drawn from design/brand/lumi-cat.svg (240×240).
/// Painted in code so the lantern, the paw, the eyes and the sparks can move.
class LumiCat extends StatefulWidget {
  const LumiCat({
    super.key,
    this.size = 120,
    this.waving = true,
    this.idle = true,
    this.lampLit = 1,
    this.sparks = 0,
    this.eyesClosed = false,
    this.sleepy = false,
    this.semanticLabel,
  });

  final double size;

  /// The raised paw waves.
  final bool waving;

  /// Gentle bob and lantern swing.
  final bool idle;

  /// 0 = dark lantern, 1 = lit lime.
  final double lampLit;

  /// 0..1: little lines around the lantern as it lights up.
  final double sparks;
  final bool eyesClosed;

  /// Asleep: closed eyes, small mouth, slow breathing, no wave.
  final bool sleepy;
  final String? semanticLabel;

  @override
  State<LumiCat> createState() => _LumiCatState();
}

class _LumiCatState extends State<LumiCat> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((elapsed) => _time.value = elapsed.inMicroseconds / 1e6);
  final _time = ValueNotifier<double>(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !Motion.reduced(context) && (widget.idle || widget.waving || widget.sleepy);
    if (animate && !_ticker.isActive) _ticker.start();
    if (!animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      size: Size.square(widget.size),
      painter: _CatPainter(time: _time, widget: widget),
    );
    return Semantics(
      label: widget.semanticLabel,
      image: widget.semanticLabel != null,
      excludeSemantics: true,
      child: RepaintBoundary(child: painter),
    );
  }
}

class _CatPainter extends CustomPainter {
  _CatPainter({required this.time, required this.widget}) : super(repaint: time);

  final ValueNotifier<double> time;
  final LumiCat widget;

  static const _orange = Color(0xFFF2A65A);
  static const _cream = Color(0xFFF2EEE3);
  static const _belly = Color(0xFFFBE3C8);
  static const _pink = Color(0xFFF7C6B5);
  static const _nose = Color(0xFFE07A6A);
  static const _ink = Color(0xFF14161A);

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final sleepy = widget.sleepy;
    final bob = widget.idle && !sleepy ? -2.5 + 2.5 * math.cos(2 * math.pi * t / 3) : 0.0;
    final swing = widget.idle ? (-5 * math.cos(2 * math.pi * t / 2.8)) * math.pi / 180 : 0.0;
    final wave = widget.waving && !sleepy ? (-12 * math.sin(2 * math.pi * t / 1.6)) * math.pi / 180 : 0.0;
    final breathe = sleepy ? 1 + 0.025 * math.sin(2 * math.pi * t / 3) : 1.0;

    canvas.save();
    canvas.scale(size.width / 240);
    canvas.translate(0, bob);
    if (breathe != 1) {
      canvas.translate(120, 222);
      canvas.scale(1 + (breathe - 1) * 0.6, 1 / breathe);
      canvas.translate(-120, -222);
    }

    // Lantern, swinging from the tail tip.
    canvas.save();
    _rotateAround(canvas, const Offset(42, 140), swing);
    _sparks(canvas);
    _lantern(canvas, outline: true);
    _lantern(canvas, outline: false);
    canvas.restore();

    _bodyShapes(canvas, outline: true);

    canvas.save();
    _rotateAround(canvas, const Offset(160, 158), wave);
    final paw = _ellipse(172, 136, 12, 24)
        .transform(_rotation(const Offset(172, 136), 28 * math.pi / 180).storage);
    _draw(canvas, paw, fill: _orange, stroke: _cream, width: 14);
    _draw(canvas, paw, fill: _orange, stroke: _ink, width: 3.5);
    canvas.restore();

    _bodyShapes(canvas, outline: false);
    _face(canvas, closed: widget.eyesClosed || sleepy, sleepy: sleepy);
    canvas.restore();
  }

  void _sparks(Canvas canvas) {
    final s = widget.sparks.clamp(0.0, 1.0);
    if (s <= 0) return;
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: s)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const lines = [
      (Offset(14, 160), Offset(4, 154)),
      (Offset(10, 180), Offset(-1, 182)),
      (Offset(18, 200), Offset(10, 208)),
      (Offset(68, 200), Offset(76, 208)),
    ];
    for (final (a, b) in lines) {
      canvas.drawLine(a, Offset.lerp(a, b, 0.4 + 0.6 * s)!, paint);
    }
  }

  void _lantern(Canvas canvas, {required bool outline}) {
    final stroke = outline ? _cream : _ink;
    final width = outline ? 14.0 : 3.5;
    final lamp = Color.lerp(AppColors.lamp, AppColors.accent, widget.lampLit.clamp(0.0, 1.0))!;
    _draw(canvas, Path()..moveTo(42, 140)..lineTo(42, 156), stroke: stroke, width: width);
    _draw(canvas, _rrect(34, 153, 16, 6), fill: AppColors.lamp, stroke: stroke, width: width);
    _draw(canvas, _ellipse(42, 174, 15, 17), fill: lamp, stroke: stroke, width: width);
    if (!outline) {
      _draw(
        canvas,
        Path()
          ..moveTo(42, 157)
          ..lineTo(42, 191)
          ..moveTo(34, 160)
          ..quadraticBezierTo(30, 174, 34, 188)
          ..moveTo(50, 160)
          ..quadraticBezierTo(54, 174, 50, 188),
        stroke: stroke,
        width: width,
      );
    }
    _draw(canvas, _rrect(35, 189, 14, 5), fill: AppColors.lamp, stroke: stroke, width: width);
  }

  void _bodyShapes(Canvas canvas, {required bool outline}) {
    final stroke = outline ? _cream : _ink;
    final width = outline ? 14.0 : 3.5;
    final tail = Path()
      ..moveTo(74, 200)
      ..cubicTo(35, 205, 18, 165, 40, 140)
      ..cubicTo(44, 136, 50, 140, 47, 145)
      ..cubicTo(32, 165, 42, 190, 74, 188)
      ..close();
    _draw(canvas, tail, fill: _orange, stroke: stroke, width: width);
    _draw(canvas, _ellipse(120, 172, 52, 46), fill: _orange, stroke: stroke, width: width);
    if (!outline) _draw(canvas, _ellipse(120, 180, 28, 28), fill: _belly, stroke: stroke, width: width);
    _draw(canvas, _ellipse(100, 214, 16, 9), fill: _orange, stroke: stroke, width: width);
    _draw(canvas, _ellipse(140, 214, 16, 9), fill: _orange, stroke: stroke, width: width);
    _draw(canvas, _tri(80, 82, 86, 44, 110, 66), fill: _orange, stroke: stroke, width: width);
    _draw(canvas, _tri(160, 82, 154, 44, 130, 66), fill: _orange, stroke: stroke, width: width);
    _draw(canvas, _ellipse(120, 106, 50, 42), fill: _orange, stroke: stroke, width: width);
  }

  void _face(Canvas canvas, {required bool closed, required bool sleepy}) {
    _draw(canvas, _tri(90, 60, 92, 72, 102, 68), fill: _pink);
    _draw(canvas, _tri(150, 60, 148, 72, 138, 68), fill: _pink);
    _draw(
      canvas,
      Path()
        ..moveTo(110, 68)
        ..lineTo(112, 80)
        ..moveTo(120, 66)
        ..lineTo(120, 80)
        ..moveTo(130, 68)
        ..lineTo(128, 80),
      stroke: _ink,
      width: 3.5,
    );
    if (closed) {
      _draw(
        canvas,
        Path()
          ..moveTo(95, 106)
          ..quadraticBezierTo(102, 112, 109, 106)
          ..moveTo(131, 106)
          ..quadraticBezierTo(138, 112, 145, 106),
        stroke: _ink,
        width: 3.5,
      );
    } else {
      _draw(canvas, _ellipse(102, 106, 5, 7), fill: _ink);
      _draw(canvas, _ellipse(138, 106, 5, 7), fill: _ink);
    }
    _draw(canvas, _ellipse(90, 120, 7, 4), fill: _pink);
    _draw(canvas, _ellipse(150, 120, 7, 4), fill: _pink);
    _draw(canvas, _tri(116, 116, 124, 116, 120, 121), fill: _nose, stroke: _ink, width: 3.5);
    _draw(
      canvas,
      sleepy
          ? (Path()
              ..moveTo(114, 126)
              ..quadraticBezierTo(120, 123, 126, 126))
          : (Path()
              ..moveTo(120, 121)
              ..quadraticBezierTo(115, 128, 109, 124)
              ..moveTo(120, 121)
              ..quadraticBezierTo(125, 128, 131, 124)),
      stroke: _ink,
      width: 3.5,
    );
    _draw(
      canvas,
      Path()
        ..moveTo(76, 110)
        ..lineTo(60, 106)
        ..moveTo(76, 116)
        ..lineTo(60, 118)
        ..moveTo(164, 110)
        ..lineTo(180, 106)
        ..moveTo(164, 116)
        ..lineTo(180, 118),
      stroke: _ink,
      width: 3.5,
    );
  }

  static void _draw(Canvas canvas, Path path, {Color? fill, Color? stroke, double width = 0}) {
    if (fill != null) canvas.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  static Path _ellipse(double cx, double cy, double rx, double ry) =>
      Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));

  static Path _rrect(double x, double y, double w, double h) =>
      Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(2)));

  static Path _tri(double x1, double y1, double x2, double y2, double x3, double y3) => Path()
    ..moveTo(x1, y1)
    ..lineTo(x2, y2)
    ..lineTo(x3, y3)
    ..close();

  static Matrix4 _rotation(Offset center, double angle) => Matrix4.identity()
    ..translateByDouble(center.dx, center.dy, 0, 1)
    ..rotateZ(angle)
    ..translateByDouble(-center.dx, -center.dy, 0, 1);

  static void _rotateAround(Canvas canvas, Offset center, double angle) {
    if (angle == 0) return;
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
  }

  @override
  bool shouldRepaint(_CatPainter old) =>
      old.widget.lampLit != widget.lampLit ||
      old.widget.sparks != widget.sparks ||
      old.widget.eyesClosed != widget.eyesClosed ||
      old.widget.sleepy != widget.sleepy ||
      old.widget.waving != widget.waving;
}

/// The cat's head on a lime tile (app icon, chat avatar).
class LumiCatIcon extends StatelessWidget {
  const LumiCatIcon({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _IconPainter());
}

class _IconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    final tile = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(30 * s));
    canvas.drawRRect(tile, Paint()..color = AppColors.accent);
    canvas.save();
    canvas.clipRRect(tile);
    canvas.translate(2 * s, 8 * s);
    canvas.scale(s);
    canvas.translate(-62, -36);
    const ink = Color(0xFF14161A);
    const orange = Color(0xFFF2A65A);
    void draw(Path p, Color? fill, {bool stroke = true}) =>
        _CatPainter._draw(canvas, p, fill: fill, stroke: stroke ? ink : null, width: 4);
    draw(_CatPainter._ellipse(120, 172, 52, 46), orange);
    draw(_CatPainter._tri(80, 82, 86, 44, 110, 66), orange);
    draw(_CatPainter._tri(160, 82, 154, 44, 130, 66), orange);
    draw(_CatPainter._ellipse(120, 106, 50, 42), orange);
    draw(
      Path()
        ..moveTo(110, 68)
        ..lineTo(112, 80)
        ..moveTo(120, 66)
        ..lineTo(120, 80)
        ..moveTo(130, 68)
        ..lineTo(128, 80),
      null,
    );
    draw(_CatPainter._ellipse(102, 106, 5, 7), ink, stroke: false);
    draw(_CatPainter._ellipse(138, 106, 5, 7), ink, stroke: false);
    draw(_CatPainter._tri(116, 116, 124, 116, 120, 121), const Color(0xFFE07A6A));
    draw(
      Path()
        ..moveTo(120, 121)
        ..quadraticBezierTo(115, 128, 109, 124)
        ..moveTo(120, 121)
        ..quadraticBezierTo(125, 128, 131, 124),
      null,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) => false;
}
