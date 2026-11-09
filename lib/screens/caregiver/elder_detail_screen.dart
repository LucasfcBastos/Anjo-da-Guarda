import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/caregiver_controller.dart';
import '../../core/app_theme.dart';
import '../../core/formatters.dart';
import '../../models/alert_record.dart';
import '../../models/elder_status.dart';
import '../../services/auth_service.dart';
import '../../widgets/big_button.dart';
import '../../widgets/info_card.dart';
import '../../widgets/message_panel.dart';
import 'situation_style.dart';

/// Detalhes de um idoso: mapa, última atualização, alertas e histórico.
class ElderDetailScreen extends StatelessWidget {
  const ElderDetailScreen({
    super.key,
    required this.controller,
    required this.elderId,
  });

  final CaregiverController controller;
  final String elderId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final view = controller.elder(elderId);
        if (view == null) {
          // O vínculo foi desfeito enquanto a tela estava aberta.
          return Scaffold(
            appBar: AppBar(title: const Text('Idoso')),
            body: const Padding(
              padding: EdgeInsets.all(20),
              child: MessagePanel(
                message: 'Você não tem mais acesso a este idoso.',
              ),
            ),
          );
        }
        final now = DateTime.now();
        final status = view.status;
        final situation = view.situationAt(now);
        final style = elderSituationStyle(situation);
        final active = view.alerts
            .where((a) => a.situationAt(now).isActive)
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(view.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (_) => _confirmUnlink(context, view),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'unlink',
                    child: Text(
                      'Deixar de acompanhar',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: style.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(style.icon, color: Colors.white, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        style.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (view.error != null) ...[
                const SizedBox(height: 12),
                MessagePanel(message: view.error!),
              ],
              for (final alert in active) ...[
                const SizedBox(height: 12),
                _ActiveAlertCard(
                  alert: alert,
                  now: now,
                  onResolve: () => _resolve(context, alert),
                ),
              ],
              const SizedBox(height: 16),
              _LocationSection(status: status, now: now),
              const SizedBox(height: 16),
              _DeviceStatus(status: status, now: now),
              const SizedBox(height: 20),
              Text(
                'Histórico de alertas',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!view.loaded)
                const Center(child: CircularProgressIndicator())
              else if (view.alerts.isEmpty)
                const InfoCard(
                  icon: Icons.history,
                  title: 'Nenhum alerta',
                  child: Text('Nenhuma queda ou pedido de ajuda registrado'),
                )
              else
                for (final alert in view.alerts)
                  _HistoryTile(alert: alert, now: now),
            ],
          ),
        );
      },
    );
  }

  Future<void> _resolve(BuildContext context, AlertRecord alert) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como atendido?'),
        content: const Text(
          'Use quando você já falou com o idoso ou a ajuda chegou.',
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
            child: const Text('Atendido'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await controller.resolveAlert(alert);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
      }
    }
  }

  Future<void> _confirmUnlink(BuildContext context, ElderView view) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Deixar de acompanhar ${view.name}?'),
        content: const Text(
          'Você não verá mais a localização nem os alertas. '
          'Para voltar, será preciso um novo código.',
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
            child: const Text('Deixar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await controller.cancelLink(view.link);
    if (context.mounted) Navigator.of(context).pop();
  }
}

Future<void> _openMaps(BuildContext context, SharedLocation location) async {
  final ok = await launchUrl(
    Uri.parse(location.mapsLink),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o mapa')),
    );
  }
}

class _ActiveAlertCard extends StatelessWidget {
  const _ActiveAlertCard({
    required this.alert,
    required this.now,
    required this.onResolve,
  });

  final AlertRecord alert;
  final DateTime now;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final situation = alert.situationAt(now);
    final style = alertSituationStyle(situation, isFall: alert.isFall);
    final location = alert.location;
    final String detail = switch (situation) {
      AlertSituation.possibleFall =>
        'O idoso tem até ${formatDayTime(alert.deadline ?? alert.createdAt).split(' ').last} '
            'para responder "Estou bem".',
      AlertSituation.unanswered =>
        'O prazo acabou e o celular do idoso não confirmou nada. Ele pode '
            'estar sem internet, com o app pausado ou precisando de ajuda.',
      _ =>
        alert.isFall
            ? 'O idoso não respondeu após uma possível queda.'
            : 'O idoso tocou em PEDIR AJUDA.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.color, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${alert.typeLabel}: ${style.label}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatFullDateTime(alert.createdAt)} (${formatAgo(alert.createdAt, now)})',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(fontSize: 17)),
          if (alert.locationError != null && location == null) ...[
            const SizedBox(height: 6),
            Text(
              'GPS do idoso: ${alert.locationError}',
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          if (location != null) ...[
            BigButton(
              label: 'Ver local do alerta no mapa',
              icon: Icons.map,
              color: style.color,
              onPressed: () => _openMaps(context, location),
            ),
            const SizedBox(height: 8),
          ],
          BigButton(
            label: 'Marcar como atendido',
            icon: Icons.task_alt,
            outlined: true,
            onPressed: onResolve,
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.status, required this.now});

  final ElderStatus? status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final location = status?.location;
    if (location == null) {
      return InfoCard(
        icon: Icons.location_off,
        color: AppColors.warning,
        title: 'Última localização',
        child: Text(
          status?.gpsMessage ??
              'O celular do idoso ainda não enviou a localização',
        ),
      );
    }
    final point = LatLng(location.lat, location.lng);
    final measuredAt = location.at;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              // Recria o mapa quando a posição muda, para centralizar.
              key: ValueKey('${location.lat},${location.lng}'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 16,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.anjodaguarda.app',
                ),
                if (location.accuracy != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: point,
                        radius: location.accuracy!,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 1,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 52,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.emergency,
                        size: 52,
                      ),
                    ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap')],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Última localização recebida',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                Text(
                  measuredAt == null
                      ? 'Horário desconhecido'
                      : '${formatFullDateTime(measuredAt)} '
                            '(${formatAgo(measuredAt, now)})',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${location.lat.toStringAsFixed(6)}, '
                  '${location.lng.toStringAsFixed(6)}'
                  '${location.accuracy == null ? '' : '  (±${location.accuracy!.toStringAsFixed(0)} m)'}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),
                BigButton(
                  label: 'Abrir no Google Maps',
                  icon: Icons.directions,
                  outlined: true,
                  onPressed: () => _openMaps(context, location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Situação do celular do idoso (sensor, GPS, última conexão).
class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({required this.status, required this.now});

  final ElderStatus? status;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = status;
    if (s == null) {
      return const InfoCard(
        icon: Icons.phone_android,
        title: 'Celular do idoso',
        child: Text('Ainda sem dados. O idoso precisa abrir o app.'),
      );
    }
    final lastSeen = s.lastSeen;
    final stale = lastSeen == null || now.difference(lastSeen) > staleAfter;
    final lines = <String>[
      lastSeen == null
          ? 'Nunca conectou'
          : 'Última conexão: ${formatFullDateTime(lastSeen)} '
                '(${formatAgo(lastSeen, now)})',
      if (!s.signedIn) 'O idoso saiu da conta neste celular.',
      s.sensorError ??
          (s.monitoring
              ? 'Detecção de quedas: ligada'
              : 'Detecção de quedas: pausada pelo idoso'),
      s.gpsStatus == 'active'
          ? 'GPS: ativo'
          : 'GPS: ${s.gpsMessage ?? 'indisponível'}',
      if (stale && s.signedIn)
        'Sem notícias recentes: o app pode ter sido fechado pelo sistema, '
            'o celular pode estar sem internet ou desligado.',
    ];
    return InfoCard(
      icon: Icons.phone_android,
      color: stale ? Colors.blueGrey : AppColors.primary,
      title: 'Celular do idoso',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.alert, required this.now});

  final AlertRecord alert;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final situation = alert.situationAt(now);
    final style = alertSituationStyle(situation, isFall: alert.isFall);
    final location = alert.location;
    final closedBy = alert.resolvedByName;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          alert.isFall ? Icons.personal_injury : Icons.sos,
          color: style.color,
          size: 34,
        ),
        title: Text(
          '${alert.typeLabel} — ${style.label}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            formatFullDateTime(alert.createdAt),
            if (situation == AlertSituation.resolved && closedBy != null)
              'Encerrado por $closedBy',
          ].join('\n'),
          style: const TextStyle(fontSize: 16),
        ),
        trailing: location == null
            ? null
            : IconButton(
                tooltip: 'Ver no mapa',
                icon: const Icon(Icons.map, size: 30),
                onPressed: () => _openMaps(context, location),
              ),
      ),
    );
  }
}
