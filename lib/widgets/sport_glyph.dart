import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matchmaster/core/theme/app_theme.dart';
import 'package:matchmaster/models/sport.dart';

/// Cor de acento de cada esporte, em cada tema.
ThemedColor sportAccent(Sport sport) => switch (sport) {
      Sport.tennis => const ThemedColor(Color(0xFFC7E63C), Color(0xFF4D7C0F)),
      Sport.tableTennis =>
        const ThemedColor(Color(0xFF43A9FF), Color(0xFF0369A1)),
      Sport.volleyball =>
        const ThemedColor(Color(0xFFFFB020), Color(0xFFB45309)),
    };

/// Ilustração do esporte desenhada em vetor.
///
/// Substitui os três clip-arts que vinham no projeto — um deles era um JPEG com
/// enquadramento diferente dos outros dois, e nenhum funcionava no tema claro.
/// Assim os três esportes ficam no mesmo traço e acompanham o tema.
class SportGlyph extends StatelessWidget {
  const SportGlyph({
    super.key,
    required this.sport,
    this.size = 64,
    this.color,
  });

  final Sport sport;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        color ?? sportAccent(sport).of(Theme.of(context).brightness);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SportGlyphPainter(sport, accent)),
    );
  }
}

class _SportGlyphPainter extends CustomPainter {
  const _SportGlyphPainter(this.sport, this.color);

  final Sport sport;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset c = Offset(size.width / 2, size.height / 2);

    final Paint fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.075
      ..isAntiAlias = true;
    final Paint carve = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = s * 0.075
      ..blendMode = BlendMode.clear
      ..isAntiAlias = true;

    switch (sport) {
      case Sport.tennis:
        _tennisBall(canvas, c, s, fill, carve);
      case Sport.tableTennis:
        _paddle(canvas, c, s, fill, stroke);
      case Sport.volleyball:
        _volleyball(canvas, c, s, fill, carve);
    }
  }

  /// Bola de tênis: disco com as duas costuras curvas.
  void _tennisBall(Canvas canvas, Offset c, double s, Paint fill, Paint carve) {
    final double r = s * 0.42;
    canvas.saveLayer(Rect.fromCircle(center: c, radius: s), Paint());
    canvas.drawCircle(c, r, fill);
    _seams(canvas, c, r, carve, count: 2, distance: 1.42, arc: 1.24);
    canvas.restore();
  }

  /// Vôlei: disco com os três gomos.
  void _volleyball(Canvas canvas, Offset c, double s, Paint fill, Paint carve) {
    final double r = s * 0.42;
    canvas.saveLayer(Rect.fromCircle(center: c, radius: s), Paint());
    canvas.drawCircle(c, r, fill);
    // Gomos mais afastados do centro: com três costuras, arcos rasos
    // demais se encontram no meio e o desenho vira uma estrela.
    _seams(canvas, c, r, carve, count: 3, distance: 1.62, arc: 1.24);
    canvas.restore();
  }

  /// Costuras: arcos de centro fora da bola, distribuídos em volta dela.
  ///
  /// O mesmo traço serve para o tênis (duas costuras) e para o vôlei (três
  /// gomos), o que mantém os dois desenhos na mesma família.
  void _seams(
    Canvas canvas,
    Offset c,
    double r,
    Paint carve, {
    required int count,
    required double distance,
    required double arc,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (int i = 0; i < count; i++) {
      canvas.rotate(2 * math.pi / count);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, -r * distance), radius: r * arc),
        math.pi * 0.17,
        math.pi * 0.66,
        false,
        carve,
      );
    }
    canvas.restore();
  }

  /// Raquete de tênis de mesa com a bolinha ao lado.
  void _paddle(Canvas canvas, Offset c, double s, Paint fill, Paint stroke) {
    final Offset head = c + Offset(-s * 0.07, -s * 0.07);
    canvas.drawCircle(head, s * 0.29, fill);

    final Offset gripTop = head + Offset(s * 0.185, s * 0.185);
    canvas.drawLine(
      gripTop,
      gripTop + Offset(s * 0.20, s * 0.20),
      stroke..strokeWidth = s * 0.095,
    );

    canvas.drawCircle(c + Offset(s * 0.30, -s * 0.26), s * 0.095, fill);
  }

  @override
  bool shouldRepaint(_SportGlyphPainter oldDelegate) =>
      oldDelegate.sport != sport || oldDelegate.color != color;
}
