import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:matchmaster/core/theme/app_theme.dart';

/// Emblema do MatchMaster.
///
/// Uma bola cortada pela diagonal da rede: os dois lados de uma partida, em
/// clay e teal. Desenhado em vetor para ficar nítido do ícone de 24 px ao
/// cabeçalho de 160 px, e para acompanhar o tema sem precisar de dois arquivos.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64, this.onDark});

  final double size;

  /// Força a variante escura/clara. Por padrão segue o tema.
  final bool? onDark;

  @override
  Widget build(BuildContext context) {
    final bool dark = onDark ?? Theme.of(context).brightness == Brightness.dark;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _BrandMarkPainter(
          left: dark ? AppColors.clay : AppColors.clayDeep,
          right: dark ? AppColors.teal : AppColors.tealDeep,
          gap: dark ? AppColors.ink900 : AppColors.paper,
        ),
      ),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter({
    required this.left,
    required this.right,
    required this.gap,
  });

  final Color left;
  final Color right;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = math.min(size.width, size.height);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = s / 2;
    final Rect circle = Rect.fromCircle(center: center, radius: radius);

    // A rede corta a bola na diagonal; a folga é proporcional ao tamanho para
    // o emblema continuar legível quando reduzido a um favicon.
    final double net = s * 0.11;
    final double diag = s * 1.6;

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));

    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    final Paint paint = Paint()..isAntiAlias = true;
    canvas.drawRect(
      Rect.fromLTRB(-diag, -diag, diag, -net / 2),
      paint..color = left,
    );
    canvas.drawRect(
      Rect.fromLTRB(-diag, net / 2, diag, diag),
      paint..color = right,
    );

    canvas.restore();

    // Ponto de saque: o "match point" no canto do lado do saibro.
    canvas.drawCircle(
      center + Offset(-radius * 0.36, -radius * 0.36),
      s * 0.085,
      Paint()..color = gap,
    );
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.right != right ||
      oldDelegate.gap != gap;
}

/// Emblema + nome, para cabeçalhos.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.markSize = 44,
    this.showTagline = true,
    this.axis = Axis.horizontal,
  });

  final double markSize;
  final bool showTagline;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool vertical = axis == Axis.vertical;

    final Widget name = Column(
      crossAxisAlignment:
          vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RichText(
          textAlign: vertical ? TextAlign.center : TextAlign.start,
          text: TextSpan(
            style: theme.textTheme.headlineSmall?.copyWith(
              letterSpacing: -0.8,
              fontSize: markSize * 0.58,
            ),
            children: <InlineSpan>[
              TextSpan(
                text: 'Match',
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              TextSpan(
                text: 'Master',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        if (showTagline) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            'PLACAR E HISTÓRICO',
            style: theme.textTheme.titleSmall?.copyWith(
              fontSize: markSize * 0.17,
              letterSpacing: markSize * 0.055,
            ),
          ),
        ],
      ],
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BrandMark(size: markSize),
          SizedBox(height: markSize * 0.32),
          name,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        BrandMark(size: markSize),
        SizedBox(width: markSize * 0.32),
        name,
      ],
    );
  }
}
