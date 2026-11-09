import 'package:anjo_da_guarda/models/emergency_alert.dart';
import 'package:anjo_da_guarda/models/medication.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('Medication converte para JSON e volta', () {
    const med = Medication(
      id: 123,
      name: 'Losartana',
      hour: 8,
      minute: 5,
      photoPath: '/tmp/foto.jpg',
    );
    final copy = Medication.fromJson(med.toJson());
    expect(copy.name, 'Losartana');
    expect(copy.timeLabel, '08:05');
  });

  test('mensagem do alerta inclui coordenadas e link do mapa', () {
    final alert = EmergencyAlert(
      reason: EmergencyReason.fallWithoutResponse,
      createdAt: DateTime(2026, 11, 9, 14, 30),
      position: Position(
        latitude: -23.55052,
        longitude: -46.633308,
        timestamp: DateTime(2026, 11, 9, 14, 30),
        accuracy: 8,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      ),
    );
    expect(alert.familyMessage, contains('-23.550520'));
    expect(
      alert.familyMessage,
      contains('maps.google.com/?q=-23.55052,-46.633308'),
    );
  });

  test('alerta sem GPS informa o motivo', () {
    final alert = EmergencyAlert(
      reason: EmergencyReason.manualRequest,
      createdAt: DateTime(2026),
      locationError: 'GPS desligado',
    );
    expect(alert.familyMessage, contains('GPS desligado'));
  });
}
