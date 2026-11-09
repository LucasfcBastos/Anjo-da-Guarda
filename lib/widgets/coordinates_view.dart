import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Mostra latitude, longitude, precisão e horário de uma posição GPS.
class CoordinatesView extends StatelessWidget {
  const CoordinatesView({super.key, required this.position});

  final Position position;

  @override
  Widget build(BuildContext context) {
    final t = position.timestamp.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      children: [
        _row('Latitude', position.latitude.toStringAsFixed(6)),
        _row('Longitude', position.longitude.toStringAsFixed(6)),
        _row('Precisão', '± ${position.accuracy.toStringAsFixed(0)} m'),
        _row('Obtida às', '${two(t.hour)}:${two(t.minute)}:${two(t.second)}'),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 18, color: Colors.black54),
          ),
        ),
        SelectableText(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}
