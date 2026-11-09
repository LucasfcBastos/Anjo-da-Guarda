import 'package:flutter/material.dart';

/// Cartão com ícone colorido, título e conteúdo.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Icon(icon, color: accent, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    DefaultTextStyle.merge(
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
