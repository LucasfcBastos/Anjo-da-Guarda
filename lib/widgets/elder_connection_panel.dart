import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/elder_sync_controller.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import 'info_card.dart';

/// Cartões da tela inicial do idoso: GPS/localização e conexão com cuidadores.
class ElderConnectionPanel extends StatefulWidget {
  const ElderConnectionPanel({
    super.key,
    required this.sync,
    required this.onOpenLocation,
    required this.onOpenFamily,
  });

  final ElderSyncController sync;
  final VoidCallback onOpenLocation;
  final VoidCallback onOpenFamily;

  @override
  State<ElderConnectionPanel> createState() => _ElderConnectionPanelState();
}

class _ElderConnectionPanelState extends State<ElderConnectionPanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Atualiza os textos "há X min".
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.sync,
      builder: (context, _) {
        final s = widget.sync;
        return Column(
          children: [
            _gpsCard(s),
            const SizedBox(height: 12),
            _caregiverCard(s),
          ],
        );
      },
    );
  }

  Widget _gpsCard(ElderSyncController s) {
    final now = DateTime.now();
    final position = s.lastPosition;
    final (Color color, IconData icon, String text) = switch (s.gpsStatus) {
      GpsStatus.active => (AppColors.safe, Icons.gps_fixed, 'GPS ativo'),
      GpsStatus.starting => (
        AppColors.primary,
        Icons.gps_not_fixed,
        'Ligando o GPS...',
      ),
      _ => (
        AppColors.warning,
        Icons.gps_off,
        s.gpsMessage ?? 'GPS indisponível',
      ),
    };
    return InfoCard(
      icon: icon,
      color: color,
      title: 'GPS e localização',
      onTap: widget.onOpenLocation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          if (position != null) ...[
            const SizedBox(height: 4),
            Text(
              '${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            Text(
              'Medida ${formatAgo(position.timestamp, now)} '
              '(±${position.accuracy.toStringAsFixed(0)} m)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _caregiverCard(ElderSyncController s) {
    final active = s.activeCaregivers;
    final pending = s.pendingRequests;
    final Color color;
    final String text;
    if (pending.isNotEmpty) {
      color = AppColors.warning;
      text = pending.length == 1
          ? '${pending.first.caregiverName} pediu para acompanhar você'
          : '${pending.length} pedidos aguardando sua aprovação';
    } else if (active.isEmpty) {
      color = AppColors.warning;
      text = 'Nenhum cuidador vinculado';
    } else {
      color = AppColors.safe;
      text = active.length == 1
          ? 'Conectado a ${active.first.caregiverName}'
          : 'Conectado a ${active.length} cuidadores';
    }
    final String syncText;
    if (s.syncError != null) {
      syncText = s.syncError!;
    } else if (s.isSynced) {
      syncText = 'Dados enviados ao servidor';
    } else {
      syncText =
          'Sem internet: os dados serão enviados quando a conexão voltar';
    }
    return InfoCard(
      icon: Icons.family_restroom,
      color: color,
      title: 'Conexão com o cuidador',
      onTap: widget.onOpenFamily,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                s.isSynced && s.syncError == null
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                size: 20,
                color: Colors.black54,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  syncText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
