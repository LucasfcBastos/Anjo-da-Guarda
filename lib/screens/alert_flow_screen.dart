import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/safety_controller.dart';
import '../core/app_theme.dart';
import '../models/emergency_alert.dart';
import '../widgets/big_button.dart';
import '../widgets/coordinates_view.dart';
import '../widgets/message_panel.dart';

/// Tela aberta automaticamente após uma queda (ou pedido de ajuda).
/// Mostra a pergunta "Você está bem?" com contagem regressiva e,
/// se ninguém responder, o alerta de emergência com o GPS.
/// Fecha sozinha quando o controlador volta ao estado normal.
class AlertFlowScreen extends StatefulWidget {
  const AlertFlowScreen({super.key, required this.safety});

  final SafetyController safety;

  @override
  State<AlertFlowScreen> createState() => _AlertFlowScreenState();
}

class _AlertFlowScreenState extends State<AlertFlowScreen> {
  @override
  void initState() {
    super.initState();
    widget.safety.addListener(_closeWhenIdle);
  }

  @override
  void dispose() {
    widget.safety.removeListener(_closeWhenIdle);
    super.dispose();
  }

  void _closeWhenIdle() {
    if (widget.safety.state == SafetyState.idle && mounted) {
      widget.safety.removeListener(_closeWhenIdle);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Impede fechar com o botão "voltar": é preciso responder.
    return PopScope(
      canPop: false,
      child: ListenableBuilder(
        listenable: widget.safety,
        builder: (context, _) {
          final s = widget.safety;
          return switch (s.state) {
            SafetyState.awaitingConfirmation => _FallCheckView(safety: s),
            SafetyState.emergency when s.alert != null => _EmergencyView(
              safety: s,
              alert: s.alert!,
            ),
            _ => const Scaffold(body: SizedBox.shrink()),
          };
        },
      ),
    );
  }
}

/// "Você está bem?" + contagem de 30 segundos.
class _FallCheckView extends StatelessWidget {
  const _FallCheckView({required this.safety});

  final SafetyController safety;

  @override
  Widget build(BuildContext context) {
    final progress = safety.secondsLeft / SafetyController.countdownSeconds;
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0),
      body: SafeArea(
        child: Column(
          children: [
            // Parte de cima rola em telas pequenas; os botões ficam sempre visíveis.
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.personal_injury,
                    size: 64,
                    color: AppColors.warning,
                  ),
                  const Text(
                    'Você está bem?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Detectamos uma possível queda.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: SizedBox.square(
                      dimension: 130,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 12,
                            color: AppColors.emergency,
                            backgroundColor: Colors.black12,
                          ),
                          Center(
                            child: Text(
                              '${safety.secondsLeft}',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sem resposta, o alerta de emergência será acionado.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 17),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  BigButton(
                    label: 'ESTOU BEM',
                    icon: Icons.check_circle,
                    height: 88,
                    color: AppColors.safe,
                    onPressed: safety.confirmSafe,
                  ),
                  const SizedBox(height: 12),
                  BigButton(
                    label: 'Preciso de ajuda',
                    icon: Icons.sos,
                    color: AppColors.emergency,
                    outlined: true,
                    onPressed: () => safety.triggerEmergency(
                      EmergencyReason.fallWithoutResponse,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Alerta de emergência com os dados e a localização GPS.
class _EmergencyView extends StatelessWidget {
  const _EmergencyView({required this.safety, required this.alert});

  final SafetyController safety;
  final EmergencyAlert alert;

  @override
  Widget build(BuildContext context) {
    final position = alert.position;
    return Scaffold(
      backgroundColor: const Color(0xFFFFEBEE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.emergency,
        title: const Text('ALERTA DE EMERGÊNCIA'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Icon(
            Icons.warning_rounded,
            size: 80,
            color: AppColors.emergency,
          ),
          Text(
            alert.reason.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Localização do idoso',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (alert.isLoadingLocation)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Obtendo GPS...',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  else if (position != null)
                    CoordinatesView(position: position)
                  else
                    MessagePanel(
                      message:
                          alert.locationError ?? 'Localização indisponível.',
                      actionLabel: 'Tentar novamente',
                      onAction: safety.refreshAlertLocation,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FamilyMessageCard(alert: alert),
          const SizedBox(height: 24),
          BigButton(
            label: 'Estou bem, encerrar alerta',
            icon: Icons.check_circle,
            height: 76,
            color: AppColors.safe,
            onPressed: safety.resolveEmergency,
          ),
        ],
      ),
    );
  }
}

/// Demonstração do alerta familiar: mostra a mensagem que seria enviada.
/// Não há envio automático (o app não tem servidor/SMS configurado);
/// a mensagem pode ser copiada e colada em qualquer aplicativo.
class _FamilyMessageCard extends StatelessWidget {
  const _FamilyMessageCard({required this.alert});

  final EmergencyAlert alert;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.family_restroom, size: 36),
        title: const Text(
          'Alerta para a família',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        subtitle: const Text('Toque para ver os dados do alerta'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              alert.familyMessage,
              style: const TextStyle(fontSize: 17, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          BigButton(
            label: 'Copiar mensagem',
            icon: Icons.copy,
            outlined: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: alert.familyMessage));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Mensagem copiada')));
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Demonstração: o envio automático para a família exige um serviço '
            'externo (SMS/servidor), que não está configurado neste projeto.',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
