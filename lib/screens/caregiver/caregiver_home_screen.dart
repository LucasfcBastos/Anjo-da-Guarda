import 'package:flutter/material.dart';

import '../../controllers/caregiver_controller.dart';
import '../../core/formatters.dart';
import '../../models/alert_record.dart';
import '../../services/push_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/message_panel.dart';
import 'elder_detail_screen.dart';
import 'link_elder_screen.dart';
import 'situation_style.dart';

/// Painel do cuidador: idosos vinculados e a situação de cada um.
class CaregiverHomeScreen extends StatelessWidget {
  const CaregiverHomeScreen({
    super.key,
    required this.controller,
    required this.push,
    required this.onSignOut,
  });

  final CaregiverController controller;
  final PushService push;
  final Future<void> Function() onSignOut;

  void _openLink(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LinkElderScreen(controller: controller),
    ),
  );

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Este celular deixará de receber os alertas dos idosos.',
          style: TextStyle(fontSize: 19),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus idosos'),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openLink(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Vincular idoso', style: TextStyle(fontSize: 18)),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([controller, push]),
        builder: (context, _) {
          final elders = controller.elders;
          final pending = controller.pendingLinks;
          final now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text(
                'Olá, ${controller.profile.name}',
                style: const TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (controller.error != null) ...[
                MessagePanel(message: controller.error!),
                const SizedBox(height: 12),
              ],
              _PushBanner(push: push),
              if (controller.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (elders.isEmpty && pending.isEmpty)
                _EmptyState(onLink: () => _openLink(context)),
              for (final view in elders) ...[
                _ElderCard(
                  view: view,
                  now: now,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ElderDetailScreen(
                        controller: controller,
                        elderId: view.elderId,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (final link in pending) ...[
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                    leading: const Icon(Icons.hourglass_top, size: 36),
                    title: Text(
                      link.elderName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Aguardando o idoso autorizar no celular dele',
                      style: TextStyle(fontSize: 16),
                    ),
                    trailing: IconButton(
                      tooltip: 'Cancelar pedido',
                      icon: const Icon(Icons.close, size: 30),
                      onPressed: () => controller.cancelLink(link),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ElderCard extends StatelessWidget {
  const _ElderCard({
    required this.view,
    required this.now,
    required this.onTap,
  });

  final ElderView view;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final situation = view.situationAt(now);
    final style = elderSituationStyle(situation);
    final status = view.status;
    final location = status?.location;
    final lastSeen = status?.lastSeen;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: situation == ElderSituation.emergency
            ? BorderSide(color: style.color, width: 3)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: style.color,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(style.icon, color: Colors.white, size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      style.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          view.name,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (view.error != null)
                          Text(
                            view.error!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.redAccent,
                            ),
                          ),
                        Text(
                          lastSeen == null
                              ? 'Ainda sem atualização do celular'
                              : 'Atualizado ${formatAgo(lastSeen, now)} '
                                    '(${formatDayTime(lastSeen)})',
                          style: const TextStyle(fontSize: 17),
                        ),
                        Text(
                          location == null
                              ? 'Localização ainda não recebida'
                              : 'Local: ${location.lat.toStringAsFixed(5)}, '
                                    '${location.lng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushBanner extends StatelessWidget {
  const _PushBanner({required this.push});

  final PushService push;

  @override
  Widget build(BuildContext context) {
    if (push.state == PushState.registered ||
        push.state == PushState.checking) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MessagePanel(
        icon: Icons.notifications_off,
        message:
            '${push.detail ?? 'Notificações push indisponíveis.'} '
            'Os alertas chegam enquanto o app estiver aberto.',
        actionLabel: 'Tentar de novo',
        onAction: push.register,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onLink});

  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.elderly, size: 72, color: Colors.black38),
            const SizedBox(height: 8),
            const Text(
              'Você ainda não acompanha nenhum idoso',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Peça ao idoso para gerar um código na aba "Família" do '
              'app dele e digite o código aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: 'Vincular idoso',
              icon: Icons.person_add,
              onPressed: onLink,
            ),
          ],
        ),
      ),
    );
  }
}
