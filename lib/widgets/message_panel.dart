import 'package:flutter/material.dart';

/// Mensagem de erro/aviso com botão opcional (ex.: abrir configurações).
class MessagePanel extends StatelessWidget {
  const MessagePanel({
    super.key,
    required this.message,
    this.icon = Icons.warning_amber_rounded,
    this.color = const Color(0xFFEF6C00),
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 18)),
              ),
            ],
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
