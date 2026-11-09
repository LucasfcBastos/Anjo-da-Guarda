import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../widgets/big_button.dart';
import '../widgets/coordinates_view.dart';
import '../widgets/info_card.dart';
import '../widgets/message_panel.dart';

/// Mostra a latitude e longitude reais obtidas pelo GPS.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key, required this.location});

  final LocationService location;

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  Position? _position;
  LocationException? _error;
  bool _loading = false;

  Future<void> _update() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await widget.location.getCurrentPosition();
      if (mounted) setState(() => _position = position);
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      appBar: AppBar(title: const Text('Localização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BigButton(
            label: _loading
                ? 'Buscando sinal do GPS...'
                : 'Atualizar localização',
            icon: Icons.my_location,
            height: 76,
            onPressed: _loading ? null : _update,
          ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(minHeight: 6),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            MessagePanel(
              message: _error!.message,
              actionLabel: _error!.issue == LocationIssue.unavailable
                  ? null
                  : 'Abrir configurações',
              onAction: () => widget.location.openSettingsFor(_error!.issue),
            ),
          ],
          const SizedBox(height: 16),
          if (position == null)
            const InfoCard(
              icon: Icons.location_searching,
              title: 'Coordenadas',
              child: Text('Toque em "Atualizar localização"'),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 56,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 8),
                    CoordinatesView(position: position),
                    const SizedBox(height: 16),
                    BigButton(
                      label: 'Copiar coordenadas',
                      icon: Icons.copy,
                      outlined: true,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text: '${position.latitude}, ${position.longitude}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Coordenadas copiadas')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Esta mesma localização é enviada no alerta de emergência '
            'quando uma queda não é respondida.',
            style: TextStyle(fontSize: 17, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
