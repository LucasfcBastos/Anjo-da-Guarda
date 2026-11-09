import 'package:flutter/material.dart';

/// Gráfico simples da aceleração total ao longo do tempo,
/// com uma linha vermelha indicando o limite de impacto.
class MagnitudeChart extends StatelessWidget {
  const MagnitudeChart({
    super.key,
    required this.values,
    required this.threshold,
  });

  final List<double> values;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          values: List.of(values),
          threshold: threshold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.values,
    required this.threshold,
    required this.color,
  });

  final List<double> values;
  final double threshold;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final maxY = threshold * 1.4;
    double y(double v) => size.height - (v.clamp(0, maxY) / maxY) * size.height;

    // Linha do limite de impacto.
    final limit = Paint()
      ..color = Colors.red.withValues(alpha: 0.6)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, y(threshold)),
      Offset(size.width, y(threshold)),
      limit,
    );

    // Linha da gravidade (repouso ≈ 9,8 m/s²).
    final rest = Paint()
      ..color = Colors.grey.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, y(9.81)), Offset(size.width, y(9.81)), rest);

    if (values.length < 2) return;
    final path = Path();
    final dx = size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final point = Offset(i * dx, y(values[i]));
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
