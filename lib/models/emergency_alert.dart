import 'package:geolocator/geolocator.dart';

enum EmergencyReason {
  fallWithoutResponse('Possível queda sem resposta em 30 segundos'),
  manualRequest('Pedido de ajuda feito pelo usuário');

  const EmergencyReason(this.description);
  final String description;
}

/// Dados de um alerta de emergência: motivo, horário e localização GPS.
class EmergencyAlert {
  const EmergencyAlert({
    required this.reason,
    required this.createdAt,
    this.position,
    this.locationError,
    this.isLoadingLocation = false,
  });

  final EmergencyReason reason;
  final DateTime createdAt;
  final Position? position;
  final String? locationError;
  final bool isLoadingLocation;

  EmergencyAlert copyWith({
    Position? position,
    String? locationError,
    bool? isLoadingLocation,
  }) => EmergencyAlert(
    reason: reason,
    createdAt: createdAt,
    position: position ?? this.position,
    locationError: locationError ?? this.locationError,
    isLoadingLocation: isLoadingLocation ?? this.isLoadingLocation,
  );

  String? get mapsLink => position == null
      ? null
      : 'https://maps.google.com/?q=${position!.latitude},${position!.longitude}';

  /// Mensagem que seria enviada à família.
  String get familyMessage {
    final buffer = StringBuffer()
      ..writeln('ALERTA - ANJO DA GUARDA')
      ..writeln(reason.description)
      ..writeln('Horário: ${_formatDateTime(createdAt)}');
    if (position != null) {
      buffer
        ..writeln('Latitude: ${position!.latitude.toStringAsFixed(6)}')
        ..writeln('Longitude: ${position!.longitude.toStringAsFixed(6)}')
        ..writeln('Precisão: ±${position!.accuracy.toStringAsFixed(0)} m')
        ..write('Mapa: $mapsLink');
    } else {
      buffer.write(
        'Localização indisponível: ${locationError ?? 'obtendo...'}',
      );
    }
    return buffer.toString();
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String _formatDateTime(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
