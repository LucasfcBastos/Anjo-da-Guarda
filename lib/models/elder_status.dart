import 'package:cloud_firestore/cloud_firestore.dart';

/// Localização enviada pelo celular do idoso.
class SharedLocation {
  const SharedLocation({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.at,
  });

  final double lat;
  final double lng;
  final double? accuracy;

  /// Horário em que o GPS mediu a posição.
  final DateTime? at;

  String get mapsLink =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'accuracy': ?accuracy,
    if (at != null) 'at': Timestamp.fromDate(at!),
  };

  static SharedLocation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'];
    final lng = raw['lng'];
    if (lat is! num || lng is! num) return null;
    return SharedLocation(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      accuracy: (raw['accuracy'] as num?)?.toDouble(),
      at: (raw['at'] as Timestamp?)?.toDate(),
    );
  }
}

/// Documento `elders/{uid}`: o que o cuidador vê do idoso.
class ElderStatus {
  const ElderStatus({
    required this.name,
    required this.signedIn,
    required this.monitoring,
    required this.safetyState,
    this.sensorError,
    this.gpsStatus,
    this.gpsMessage,
    this.location,
    this.lastSeen,
  });

  final String name;
  final bool signedIn;

  /// Acelerômetro ligado no celular do idoso.
  final bool monitoring;

  /// idle, awaitingConfirmation ou emergency (SafetyState).
  final String safetyState;
  final String? sensorError;
  final String? gpsStatus;
  final String? gpsMessage;
  final SharedLocation? location;

  /// Última vez que o celular do idoso falou com o servidor.
  final DateTime? lastSeen;

  factory ElderStatus.fromMap(Map<String, dynamic> d) => ElderStatus(
    name: d['name'] as String? ?? '',
    signedIn: d['signedIn'] as bool? ?? true,
    monitoring: d['monitoring'] as bool? ?? false,
    safetyState: d['safetyState'] as String? ?? 'idle',
    sensorError: d['sensorError'] as String?,
    gpsStatus: d['gpsStatus'] as String?,
    gpsMessage: d['gpsMessage'] as String?,
    location: SharedLocation.fromMap(d['location']),
    lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
  );
}
