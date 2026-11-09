import 'package:anjo_da_guarda/controllers/safety_controller.dart';
import 'package:anjo_da_guarda/core/app_theme.dart';
import 'package:anjo_da_guarda/models/emergency_alert.dart';
import 'package:anjo_da_guarda/screens/alert_flow_screen.dart';
import 'package:anjo_da_guarda/services/location_service.dart';
import 'package:anjo_da_guarda/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Substitutos usados só nos testes (não há celular no computador).
class _FakeNotifications extends NotificationService {
  final shown = <String>[];
  @override
  Future<void> showFallCheck(int seconds) async => shown.add('queda');
  @override
  Future<void> showEmergency(EmergencyAlert alert) async =>
      shown.add('emergencia');
  @override
  Future<void> scheduleEmergencyBackup(DateTime when) async =>
      shown.add('reserva');
  @override
  Future<void> cancel(int id) async {}
}

class _FakeLocation extends LocationService {
  @override
  Future<Position> getCurrentPosition() async => throw const LocationException(
    LocationIssue.serviceDisabled,
    'GPS desligado',
  );
}

void main() {
  late _FakeNotifications notifications;
  late SafetyController safety;

  setUp(() {
    notifications = _FakeNotifications();
    safety = SafetyController(
      notifications: notifications,
      location: _FakeLocation(),
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AlertFlowScreen(safety: safety),
      ),
    );
  }

  testWidgets('sem resposta em 30 s aciona o alerta de emergência', (
    tester,
  ) async {
    await pump(tester);
    safety.onFallDetected();
    await tester.pump();

    expect(find.text('Você está bem?'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(notifications.shown, ['queda', 'reserva']);

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('20'), findsOneWidget);

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();

    expect(safety.state, SafetyState.emergency);
    expect(find.text('ALERTA DE EMERGÊNCIA'), findsOneWidget);
    expect(find.text('GPS desligado'), findsOneWidget);
    expect(notifications.shown, ['queda', 'reserva', 'emergencia']);
  });

  testWidgets('"Estou bem" cancela a contagem', (tester) async {
    await pump(tester);
    safety.onFallDetected();
    await tester.pump();

    await tester.tap(find.text('ESTOU BEM'));
    await tester.pump();
    expect(safety.state, SafetyState.idle);
  });
}
