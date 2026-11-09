import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/medication_controller.dart';
import 'controllers/safety_controller.dart';
import 'services/location_service.dart';
import 'services/medication_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Serviços (acesso ao hardware e ao armazenamento).
  final notifications = NotificationService();
  await notifications.init();
  final location = LocationService();

  // Controladores (regras do app que ligam os serviços).
  final safety = SafetyController(
    notifications: notifications,
    location: location,
  );
  final medications = MedicationController(
    repository: MedicationRepository(),
    notifications: notifications,
  );
  await medications.load();

  runApp(
    AnjoDaGuardaApp(
      safety: safety,
      medications: medications,
      notifications: notifications,
      location: location,
    ),
  );
}
