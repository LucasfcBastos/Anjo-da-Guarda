import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/elder_sync_controller.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/care_link.dart';
import '../services/auth_service.dart';
import '../services/link_service.dart';
import '../services/location_service.dart';
import '../widgets/big_button.dart';
import '../widgets/info_card.dart';
import '../widgets/message_panel.dart';

/// Aba "Família" do idoso: código de vinculação, pedidos de
/// cuidadores, cuidadores conectados e conta.
class FamilyScreen extends StatefulWidget {
  const FamilyScreen({
    super.key,
    required this.sync,
    required this.location,
    required this.onSignOut,
  });

  final ElderSyncController sync;
  final LocationService location;
  final Future<void> Function() onSignOut;

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool _generating = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await widget.sync.generateCode();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is LinkException
              ? e.message
              : 'Não foi possível gerar o código. ${authErrorMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 19)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Família')),
      body: ListenableBuilder(
        listenable: widget.sync,
        builder: (context, _) {
          final s = widget.sync;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.linksError != null) ...[
                MessagePanel(message: s.linksError!),
                const SizedBox(height: 16),
              ],
              for (final link in s.pendingRequests) ...[
                _PendingRequestCard(
                  link: link,
                  onApprove: () async {
                    final ok = await _confirm(
                      'Autorizar ${link.caregiverName}?',
                      '${link.caregiverName} poderá ver sua localização, '
                          'seu status e seus alertas de queda.',
                      'Autorizar',
                    );
                    if (ok) {
                      await _run(
                        () => s.approve(link),
                        '${link.caregiverName} agora acompanha você',
                      );
                    }
                  },
                  onReject: () => _run(() => s.remove(link), 'Pedido recusado'),
                ),
                const SizedBox(height: 12),
              ],
              _CodeCard(
                code: s.currentCode,
                generating: _generating,
                error: _error,
                onGenerate: _generate,
              ),
              const SizedBox(height: 20),
              Text(
                'Meus cuidadores',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (s.activeCaregivers.isEmpty)
                const InfoCard(
                  icon: Icons.person_off,
                  title: 'Nenhum cuidador',
                  child: Text('Gere um código e passe para seu cuidador'),
                )
              else
                for (final link in s.activeCaregivers) ...[
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                      leading: const CircleAvatar(
                        radius: 24,
                        child: Icon(Icons.person, size: 28),
                      ),
                      title: Text(
                        link.caregiverName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        link.approvedAt == null
                            ? 'Acompanha você'
                            : 'Desde ${formatFullDateTime(link.approvedAt!)}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remover cuidador',
                        iconSize: 30,
                        icon: const Icon(Icons.link_off),
                        onPressed: () async {
                          final ok = await _confirm(
                            'Remover ${link.caregiverName}?',
                            '${link.caregiverName} deixará de ver sua '
                                'localização e seus alertas.',
                            'Remover',
                          );
                          if (ok) {
                            await _run(
                              () => s.remove(link),
                              '${link.caregiverName} foi removido',
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 20),
              _BackgroundInfo(sync: s, location: widget.location),
              const SizedBox(height: 20),
              InfoCard(
                icon: Icons.account_circle,
                title: 'Minha conta (idoso)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.profile.name),
                    Text(
                      s.profile.email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BigButton(
                label: 'Sair da conta',
                icon: Icons.logout,
                outlined: true,
                onPressed: () async {
                  final ok = await _confirm(
                    'Sair da conta?',
                    'Seus cuidadores deixarão de receber sua localização '
                        'e seus alertas até você entrar de novo.',
                    'Sair',
                  );
                  if (ok) await widget.onSignOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.link,
    required this.onApprove,
    required this.onReject,
  });

  final CareLink link;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: AppColors.warning,
                size: 32,
              ),
              SizedBox(width: 8),
              Text(
                'Pedido de vínculo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${link.caregiverName} quer acompanhar você como cuidador.',
            style: const TextStyle(fontSize: 19),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Autorizar',
            icon: Icons.check_circle,
            color: AppColors.safe,
            onPressed: onApprove,
          ),
          const SizedBox(height: 8),
          BigButton(
            label: 'Recusar',
            icon: Icons.cancel,
            outlined: true,
            onPressed: onReject,
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.generating,
    required this.error,
    required this.onGenerate,
  });

  final LinkCode? code;
  final bool generating;
  final String? error;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final c = code;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Código de vinculação',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (c != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SelectableText(
                  '${c.code.substring(0, 3)} ${c.code.substring(3)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Passe este código para seu cuidador. '
                'Vale até ${formatDayTime(c.expiresAt).split(' ').last}. '
                'Você ainda precisará autorizar o pedido.',
                style: const TextStyle(fontSize: 17),
              ),
            ] else
              const Text(
                'Gere um código e passe para seu cuidador digitar no '
                'celular dele. O código vale 30 minutos.',
                style: TextStyle(fontSize: 17),
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              MessagePanel(message: error!),
            ],
            const SizedBox(height: 16),
            BigButton(
              label: generating
                  ? 'Gerando...'
                  : (c == null ? 'Gerar código' : 'Gerar novo código'),
              icon: Icons.key,
              outlined: c != null,
              onPressed: generating ? null : onGenerate,
            ),
          ],
        ),
      ),
    );
  }
}

/// Explica, sem exagero, o que funciona com o app em segundo plano.
class _BackgroundInfo extends StatelessWidget {
  const _BackgroundInfo({required this.sync, required this.location});

  final ElderSyncController sync;
  final LocationService location;

  @override
  Widget build(BuildContext context) {
    final issue = sync.gpsIssue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (issue != null) ...[
          MessagePanel(
            message:
                '${sync.gpsMessage ?? 'GPS indisponível'} '
                'Seus cuidadores não recebem sua localização.',
            actionLabel: issue == LocationIssue.unavailable
                ? 'Tentar de novo'
                : 'Abrir configurações',
            onAction: issue == LocationIssue.unavailable
                ? sync.startLocation
                : () => location.openSettingsFor(issue),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          defaultTargetPlatform == TargetPlatform.iOS
              ? 'Com o app aberto ou em segundo plano, sua localização é '
                    'enviada aos cuidadores (a seta de localização aparece '
                    'na tela). Se o app for fechado ou o iPhone encerrá-lo, '
                    'o envio para até você abrir o app de novo.'
              : 'Com o app aberto ou em segundo plano, sua localização é '
                    'enviada aos cuidadores (aparece a notificação "Anjo da '
                    'Guarda ativo"). Se o app for fechado ou o celular '
                    'encerrá-lo para economizar bateria, o envio para até '
                    'você abrir o app de novo.',
          style: const TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }
}
