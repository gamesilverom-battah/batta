import 'dart:math';

import 'package:flutter/material.dart';

/// شارة رقم المستوى، مستوحاة من شعار سلطنة عُمان (الخنجر والسيفين، بالأبيض مثل اللي على العلم):
/// 1-9 دائرة حمرا، 10-19 الدائرة على خنجر وحزامه، 20-29 ومعه سيف، 30 وفوق سيفين متقاطعين، ولون الخنجر والسيوف: 40 برونز، 50 فضة، 60 ذهب، و70 وفوق أسود كروم (الشكل ما يتغير بعدها، والرقم يكمل).
/// size: مربع الشكل كله (الخنجر والسيوف داخله)
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;
  const LevelBadge({super.key, required this.level, this.size = 30});

  static int tierOf(int level) => min(level ~/ 10, 3);
  /// لون الخنجر والسيفين والحزام: 0 أبيض، 1 برونز (40-49)، 2 فضة (50-59)، 3 ذهب (60-69)، 4 أسود كروم (70 وفوق)
  static int metalOf(int level) => level >= 70 ? 4 : level >= 60 ? 3 : level >= 50 ? 2 : level >= 40 ? 1 : 0;
  static const tierNames = ['دائرة', 'خنجر وحزام', 'خنجر وسيف', 'خنجر وسيفين'];
  // نص قطر الدائرة الحمرا من المربع: لحالها أكبر، ومع الخنجر أصغر عشان يبين
  static double _radius(int tier) => tier == 0 ? 0.37 : 0.29;
  // وسط الدائرة الحمرا (مع الخنجر نازلة شوي)
  static double _centerY(int tier) => tier == 0 ? 0.5 : 0.56;

  @override
  Widget build(BuildContext context) {
    final lv = level; // الرقم يمشي، والشكل يوقف عند شكل 70
    final t = tierOf(lv);
    final d = size * _radius(t) * 2;
    final digits = '$lv'.length;
    final fs = d * (digits >= 3 ? 0.42 : digits == 2 ? 0.54 : 0.64);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BadgePainter(t, metal: metalOf(lv)),
        // الرقم بنص الدائرة بالضبط (الخط العربي فيه فراغ تحت الأرقام، فينزل شوي)
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fromRect(
            rect: Rect.fromCircle(center: Offset(size / 2, size * _centerY(t)), radius: d / 2),
            child: Center(
              child: Transform.translate(
                offset: Offset(0, fs * 0.1),
                child: Text(
                  '$lv',
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false, applyHeightToLastDescent: false),
                  style: TextStyle(
                    fontSize: fs,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
                  ),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  final int tier;
  final int metal; // LevelBadge.metalOf
  _BadgePainter(this.tier, {this.metal = 0});

  static const _white = Color(0xFFF7F7F7), _line = Color(0xFF1A1A1A);

  @override
  void paint(Canvas canvas, Size sz) {
    final s = sz.width;
    final o = Paint()..style = PaintingStyle.stroke..strokeWidth = max(1.2, s * 0.045)..color = metal == 4 ? const Color(0xFFB9BEC6) : _line..strokeJoin = StrokeJoin.round;
    Paint metallic(List<Color> colors) => Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(Rect.fromLTWH(0, 0, s, s));
    final w = switch (metal) {
      1 => metallic(const [Color(0xFFF6C99A), Color(0xFFC07A3E), Color(0xFF7A4520)]), // برونز
      2 => metallic(const [Color(0xFFFFFFFF), Color(0xFFB8BEC6), Color(0xFF7E858F)]), // فضة
      3 => metallic(const [Color(0xFFFFF1B5), Color(0xFFE8B83A), Color(0xFFB07D18)]), // ذهب
      // أسود لمّاع (كروم): خطوط لمعة بيضا بين السواد
      4 => Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7A808A), Color(0xFF16171A), Color(0xFF050506), Color(0xFFC9CED6), Color(0xFF1C1D21), Color(0xFF000000), Color(0xFF5C616A)],
          stops: [0, 0.22, 0.42, 0.52, 0.64, 0.86, 1],
        ).createShader(Rect.fromLTWH(0, 0, s, s)),
      _ => Paint()..color = _white,
    };
    void shape(Path p) {
      canvas.drawPath(p, o);
      canvas.drawPath(p, w);
    }

    // السيوف: بغمدها، متقاطعة ورا الخنجر، والمقابض فوق (السيف مقلوب: مقبضه فوق وطرفه تحت)
    final up = Matrix4.identity()
      ..translateByDouble(0, s, 0, 1)
      ..scaleByDouble(1, -1, 1, 1);
    if (tier >= 2) shape(_sword(s, mirror: false).transform(up.storage));
    if (tier >= 3) shape(_sword(s, mirror: true).transform(up.storage));
    // الحزام: بالعرض ورا الخنجر، وعلى طرفينه مربعين (يجي مع الخنجر)
    if (tier >= 1) {
      shape(Path()..addRect(Rect.fromLTRB(s * 0.14, s * 0.47, s * 0.86, s * 0.53)));
      for (final x in [0.02, 0.8]) {
        shape(Path()..addRRect(RRect.fromLTRBR(s * x, s * 0.42, s * (x + 0.18), s * 0.58, Radius.circular(s * 0.02))));
      }
    }
    if (tier >= 1) shape(_khanjar(s));

    final c = Offset(s / 2, s * LevelBadge._centerY(tier)), r = s * LevelBadge._radius(tier);
    canvas.drawCircle(c, r + s * 0.02, Paint()..color = _line);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = const RadialGradient(colors: [Color(0xFFE5393F), Color(0xFFB0141B)], center: Alignment(-0.3, -0.4), radius: 0.9).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // الحلقة اللي داخل الدائرة خضرا (ألوان العلم)
    canvas.drawCircle(c, r - s * 0.04, Paint()..style = PaintingStyle.stroke..strokeWidth = max(0.9, s * 0.035)..color = const Color(0xFF1E9E4A));
  }

  // الخنجر مثل الشعار: راس مدوّر فوق، مقبض يوسع لتحت، وغمد ينزل وينعقف لليسار وطرفه لفوق
  Path _khanjar(double s) {
    final p = Path()..addOval(Rect.fromCircle(center: Offset(s * 0.5, s * 0.07), radius: s * 0.065));
    p.addPath(
      Path()
        ..moveTo(s * 0.46, s * 0.12)
        ..lineTo(s * 0.54, s * 0.12)
        ..lineTo(s * 0.6, s * 0.3)
        ..lineTo(s * 0.4, s * 0.3)
        ..close(),
      Offset.zero,
    );
    p.addPath(
      Path()
        ..moveTo(s * 0.4, s * 0.3)
        ..lineTo(s * 0.6, s * 0.3)
        ..lineTo(s * 0.6, s * 0.8)
        // الانعقاف: من تحت يمين يدور لليسار ويطلع
        ..quadraticBezierTo(s * 0.58, s * 0.98, s * 0.36, s * 0.96)
        ..quadraticBezierTo(s * 0.2, s * 0.94, s * 0.13, s * 0.8)
        ..lineTo(s * 0.21, s * 0.76)
        ..quadraticBezierTo(s * 0.28, s * 0.84, s * 0.38, s * 0.84)
        ..quadraticBezierTo(s * 0.44, s * 0.84, s * 0.44, s * 0.76)
        ..lineTo(s * 0.4, s * 0.3)
        ..close(),
      Offset.zero,
    );
    return p;
  }

  // سيف بغمده: شريط مايل من فوق يمين لتحت يسار، وطرفه المدبب فوق، ومقبضه تحت بواقي عرضي
  Path _sword(double s, {required bool mirror}) {
    double x(double v) => mirror ? s - s * v : s * v;
    final ang = atan2(0.86 - 0.04, 0.12 - 0.9); // اتجاه الشريط
    final n = Offset(-sin(ang), cos(ang)) * (s * 0.04); // نص العرض
    Offset pt(double a, double b) => Offset(x(a), s * b);
    final top = pt(0.92, 0.04), bot = pt(0.2, 0.8);
    final nn = mirror ? Offset(-n.dx, n.dy) : n;
    final p = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(top.dx + nn.dx * 1.4 - (mirror ? -1 : 1) * s * 0.03, top.dy + nn.dy * 1.4 + s * 0.05)
      ..lineTo(bot.dx + nn.dx, bot.dy + nn.dy)
      ..lineTo(bot.dx - nn.dx, bot.dy - nn.dy)
      ..lineTo(top.dx - nn.dx * 1.4 - (mirror ? -1 : 1) * s * 0.06, top.dy - nn.dy * 1.4 + s * 0.02)
      ..close();
    // الواقي (عرضي على الشريط) والمقبض تحت
    final g1 = pt(0.2, 0.8), dir = Offset(top.dx - bot.dx, top.dy - bot.dy) / (top - bot).distance;
    final perp = Offset(-dir.dy, dir.dx);
    p.addPath(
      Path()
        ..moveTo(g1.dx + perp.dx * s * 0.09, g1.dy + perp.dy * s * 0.09)
        ..lineTo(g1.dx - perp.dx * s * 0.09, g1.dy - perp.dy * s * 0.09)
        ..lineTo(g1.dx - perp.dx * s * 0.09 - dir.dx * s * 0.04, g1.dy - perp.dy * s * 0.09 - dir.dy * s * 0.04)
        ..lineTo(g1.dx + perp.dx * s * 0.09 - dir.dx * s * 0.04, g1.dy + perp.dy * s * 0.09 - dir.dy * s * 0.04)
        ..close(),
      Offset.zero,
    );
    final h0 = g1 - dir * (s * 0.04), h1 = g1 - dir * (s * 0.2);
    p.addPath(
      Path()
        ..moveTo(h0.dx + perp.dx * s * 0.025, h0.dy + perp.dy * s * 0.025)
        ..lineTo(h1.dx + perp.dx * s * 0.035, h1.dy + perp.dy * s * 0.035)
        ..lineTo(h1.dx - perp.dx * s * 0.035, h1.dy - perp.dy * s * 0.035)
        ..lineTo(h0.dx - perp.dx * s * 0.025, h0.dy - perp.dy * s * 0.025)
        ..close(),
      Offset.zero,
    );
    return p;
  }

  @override
  bool shouldRepaint(_BadgePainter old) => old.tier != tier || old.metal != metal;
}
