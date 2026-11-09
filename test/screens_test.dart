import 'package:anjo_da_guarda/controllers/medication_controller.dart';
import 'package:anjo_da_guarda/controllers/safety_controller.dart';
import 'package:anjo_da_guarda/core/app_theme.dart';
import 'package:anjo_da_guarda/screens/home_screen.dart';
import 'package:anjo_da_guarda/screens/location_screen.dart';
import 'package:anjo_da_guarda/screens/sensor_screen.dart';
import 'package:anjo_da_guarda/services/location_service.dart';
import 'package:anjo_da_guarda/services/medication_repository.dart';
import 'package:anjo_da_guarda/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifica se as telas principais montam sem erros de layout
/// num celular pequeno (360 x 640).
void main() {
  late SafetyController safety;
  late MedicationController meds;

  setUp(() {
    final notifications = NotificationService();
    safety = SafetyController(
      notifications: notifications,
      location: LocationService(),
    );
    meds = MedicationController(
      repository: MedicationRepository(),
      notifications: notifications,
    );
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: screen));
  }

  testWidgets('tela inicial mostra status e botão de ajuda', (tester) async {
    await pump(
      tester,
      HomeScreen(safety: safety, medications: meds, onOpenTab: (_) {}),
    );
    expect(find.text('Monitoramento pausado'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PEDIR AJUDA'), 200);
    expect(find.text('PEDIR AJUDA'), findsOneWidget);
  });

  testWidgets('tela do sensor mostra os eixos', (tester) async {
    await pump(tester, SensorScreen(safety: safety));
    expect(find.text('X'), findsOneWidget);
    expect(find.text('Y'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);
  });

  testWidgets('tela de localização monta', (tester) async {
    await pump(tester, LocationScreen(location: LocationService()));
    expect(find.text('Atualizar localização'), findsOneWidget);
  });
}
