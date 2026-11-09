import 'package:flutter/material.dart';

/// Botão grande com ícone, fácil de tocar.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color,
    this.outlined = false,
    this.height = 64,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool outlined;
  final double height;

  @override
  Widget build(BuildContext context) {
    final content = Text(label, textAlign: TextAlign.center);
    final iconWidget = Icon(icon, size: 30);
    final size = Size.fromHeight(height);

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: content,
        style: OutlinedButton.styleFrom(
          minimumSize: size,
          foregroundColor: color,
          side: color == null ? null : BorderSide(color: color!, width: 2),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: iconWidget,
      label: content,
      style: FilledButton.styleFrom(minimumSize: size, backgroundColor: color),
    );
  }
}
