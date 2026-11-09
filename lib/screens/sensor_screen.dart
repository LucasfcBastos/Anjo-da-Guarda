import 'package:flutter/material.dart';

import '../controllers/safety_controller.dart';
import '../core/app_theme.dart';
import '../services/fall_detector.dart';
import '../widgets/big_button.dart';
import '../widgets/magnitude_chart.dart';
import '../widgets/message_panel.dart';

/// Valores X, Y e Z do acelerômetro em tempo real e estado da detecção.
class SensorScreen extends StatelessWidget {
  const SensorScreen({super.key, required this.safety});

  final SafetyController safety;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acelerômetro')),
      body: ListenableBuilder(
        listenable: safety,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (safety.sensorError != null) ...[
              MessagePanel(message: safety.sensorError!),
              const SizedBox(height: 16),
            ],
            BigButton(
              label: safety.isMonitoring ? 'Pausar leitura' : 'Iniciar leitura',
              icon: safety.isMonitoring ? Icons.pause : Icons.play_arrow,
              outlined: safety.isMonitoring,
              onPressed: safety.isMonitoring
                  ? safety.stopMonitoring
                  : safety.startMonitoring,
            ),
            const SizedBox(height: 16),
            // Só esta parte é redesenhada a cada leitura do sensor.
            ValueListenableBuilder<SensorReading?>(
              valueListenable: safety.reading,
              builder: (context, r, _) =>
                  _LiveValues(safety: safety, reading: r),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Como funciona a detecção:\n'
                  '1. Pico de aceleração acima de '
                  '${safety.detector.impactThreshold.toStringAsFixed(0)} m/s² '
                  '(impacto).\n'
                  '2. Depois, ${safety.detector.stillnessDuration.inSeconds} s '
                  'quase parado (perto de 9,8 m/s², só a gravidade).\n'
                  '3. Então o app pergunta "Você está bem?" e espera '
                  '${SafetyController.countdownSeconds} s.',
                  style: const TextStyle(fontSize: 17, height: 1.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveValues extends StatelessWidget {
  const _LiveValues({required this.safety, required this.reading});

  final SafetyController safety;
  final SensorReading? reading;

  @override
  Widget build(BuildContext context) {
    final r = reading;
    final checking = safety.detector.phase == FallPhase.checkingStillness;
    return Column(
      children: [
        Row(
          children: [
            _AxisTile(label: 'X', value: r?.x, color: Colors.red),
            const SizedBox(width: 8),
            _AxisTile(label: 'Y', value: r?.y, color: Colors.green),
            const SizedBox(width: 8),
            _AxisTile(label: 'Z', value: r?.z, color: Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aceleração total: ${r == null ? '--' : r.magnitude.toStringAsFixed(1)} m/s²',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                MagnitudeChart(
                  values: safety.magnitudeHistory,
                  threshold: safety.detector.impactThreshold,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      checking ? Icons.hourglass_top : Icons.check_circle,
                      color: checking ? AppColors.warning : AppColors.safe,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        !safety.isMonitoring
                            ? 'Leitura pausada'
                            : checking
                            ? 'Impacto de ${safety.detector.lastPeak.toStringAsFixed(0)} m/s²! Verificando imobilidade...'
                            : 'Aguardando movimento brusco',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AxisTile extends StatelessWidget {
  const _AxisTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value == null ? '--' : value!.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('m/s²', style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}
