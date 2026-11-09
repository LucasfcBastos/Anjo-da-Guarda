import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Dois cartões grandes para escolher o tipo de conta.
class RoleSelector extends StatelessWidget {
  const RoleSelector({super.key, required this.value, required this.onChanged});

  final UserRole? value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoleCard(
            role: UserRole.elder,
            icon: Icons.elderly,
            hint: 'Serei monitorado',
            selected: value == UserRole.elder,
            onTap: () => onChanged(UserRole.elder),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _RoleCard(
            role: UserRole.caregiver,
            icon: Icons.volunteer_activism,
            hint: 'Vou acompanhar',
            selected: value == UserRole.caregiver,
            onTap: () => onChanged(UserRole.caregiver),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Semantics(
      selected: selected,
      button: true,
      label: '${role.label}: $hint',
      child: Material(
        color: selected ? primary.withValues(alpha: 0.12) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? primary : Colors.black26,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 44,
                  color: selected ? primary : Colors.black54,
                ),
                const SizedBox(height: 6),
                Text(
                  role.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: selected ? primary : Colors.black87,
                  ),
                ),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
