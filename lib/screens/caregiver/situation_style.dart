import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../models/alert_record.dart';

/// Cor, ícone e texto de cada situação mostrada ao cuidador.
typedef SituationStyle = ({Color color, IconData icon, String label});

SituationStyle elderSituationStyle(ElderSituation s) => switch (s) {
  ElderSituation.emergency => (
    color: AppColors.emergency,
    icon: Icons.warning_rounded,
    label: 'EMERGÊNCIA',
  ),
  ElderSituation.possibleFall => (
    color: AppColors.warning,
    icon: Icons.personal_injury,
    label: 'Possível queda — aguardando resposta',
  ),
  ElderSituation.ok => (
    color: AppColors.safe,
    icon: Icons.shield,
    label: 'Monitoramento ativo',
  ),
  ElderSituation.paused => (
    color: AppColors.warning,
    icon: Icons.pause_circle,
    label: 'Monitoramento de quedas pausado',
  ),
  ElderSituation.stale => (
    color: Colors.blueGrey,
    icon: Icons.cloud_off,
    label: 'Sem atualização recente',
  ),
  ElderSituation.signedOut => (
    color: Colors.blueGrey,
    icon: Icons.logout,
    label: 'Saiu da conta no celular',
  ),
  ElderSituation.unknown => (
    color: Colors.blueGrey,
    icon: Icons.help_outline,
    label: 'Ainda sem dados do celular',
  ),
};

SituationStyle alertSituationStyle(AlertSituation s, {required bool isFall}) =>
    switch (s) {
      AlertSituation.possibleFall => (
        color: AppColors.warning,
        icon: Icons.hourglass_top,
        label: 'Aguardando resposta',
      ),
      AlertSituation.unanswered => (
        color: AppColors.emergency,
        icon: Icons.warning_rounded,
        label: 'Sem resposta',
      ),
      AlertSituation.emergency => (
        color: AppColors.emergency,
        icon: Icons.warning_rounded,
        label: isFall ? 'Não respondeu' : 'Pediu ajuda',
      ),
      AlertSituation.safe => (
        color: AppColors.safe,
        icon: Icons.check_circle,
        label: 'Respondeu que está bem',
      ),
      AlertSituation.resolved => (
        color: Colors.blueGrey,
        icon: Icons.task_alt,
        label: 'Encerrado',
      ),
    };
