import 'package:flutter/material.dart';

import '../controllers/medication_controller.dart';
import '../controllers/safety_controller.dart';
import '../core/app_theme.dart';
import '../models/emergency_alert.dart';
import '../widgets/big_button.dart';
import '../widgets/info_card.dart';

/// Tela inicial: status do monitoramento, próximo remédio e botão de ajuda.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.safety,
    required this.medications,
    required this.onOpenTab,
    this.connectionPanel,
  });

  final SafetyController safety;
  final MedicationController medications;
  final ValueChanged<int> onOpenTab;

  /// GPS e conexão com o cuidador (só quando logado como idoso).
  final Widget? connectionPanel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anjo da Guarda')),
      body: ListenableBuilder(
        listenable: Listenable.merge([safety, medications]),
        builder: (context, _) {
          final monitoring = safety.isMonitoring;
          final next = medications.nextMedication();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _MonitoringStatus(safety: safety),
              const SizedBox(height: 16),
              BigButton(
                label: monitoring
                    ? 'Pausar monitoramento'
                    : 'Ativar monitoramento',
                icon: monitoring ? Icons.pause_circle : Icons.play_circle,
                outlined: monitoring,
                onPressed: monitoring
                    ? safety.stopMonitoring
                    : safety.startMonitoring,
              ),
              if (connectionPanel != null) ...[
                const SizedBox(height: 16),
                connectionPanel!,
              ],
              const SizedBox(height: 16),
              InfoCard(
                icon: Icons.medication,
                title: 'Próximo remédio',
                onTap: () => onOpenTab(1),
                child: Text(
                  next == null
                      ? 'Nenhum cadastrado'
                      : '${next.name} às ${next.timeLabel}',
                ),
              ),
              // Com o painel de conexão, o GPS já aparece acima.
              if (connectionPanel == null) ...[
                const SizedBox(height: 12),
                InfoCard(
                  icon: Icons.location_on,
                  title: 'Minha localização',
                  onTap: () => onOpenTab(2),
                  child: const Text('Ver coordenadas GPS'),
                ),
              ],
              const SizedBox(height: 12),
              InfoCard(
                icon: Icons.sensors,
                title: 'Sensor de movimento',
                onTap: () => onOpenTab(3),
                child: const Text('Ver acelerômetro'),
              ),
              const SizedBox(height: 24),
              BigButton(
                label: 'PEDIR AJUDA',
                icon: Icons.sos,
                height: 88,
                color: AppColors.emergency,
                onPressed: () => _confirmHelp(context),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmHelp(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedir ajuda?'),
        content: const Text(
          'O alerta de emergência será acionado com a sua localização.',
          style: TextStyle(fontSize: 19),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emergency,
              minimumSize: const Size(120, 52),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, pedir ajuda'),
          ),
        ],
      ),
    );
    if (ok == true) safety.triggerEmergency(EmergencyReason.manualRequest);
  }
}

class _MonitoringStatus extends StatelessWidget {
  const _MonitoringStatus({required this.safety});
  final SafetyController safety;

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String title;
    String subtitle;
    if (safety.state == SafetyState.emergency) {
      (color, icon) = (AppColors.emergency, Icons.warning_rounded);
      title = 'Alerta de emergência ativo';
      subtitle = 'Ajuda solicitada';
    } else if (safety.sensorError != null) {
      (color, icon) = (AppColors.warning, Icons.error_outline);
      title = 'Monitoramento indisponível';
      subtitle = safety.sensorError!;
    } else if (safety.isMonitoring) {
      (color, icon) = (AppColors.safe, Icons.shield);
      title = 'Monitoramento ativo';
      subtitle = 'Detectando quedas pelo acelerômetro';
    } else {
      (color, icon) = (AppColors.warning, Icons.shield_outlined);
      title = 'Monitoramento pausado';
      subtitle = 'Quedas não estão sendo detectadas';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
