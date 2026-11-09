import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/medication_controller.dart';
import 'controllers/safety_controller.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/link_service.dart';
import 'services/location_service.dart';
import 'services/medication_repository.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (login, Firestore e push). Configuração gerada pelo
  // `flutterfire configure` em lib/firebase_options.dart.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(_FirebaseErrorApp(error: '$e'));
    return;
  }

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
      auth: AuthService(),
      links: LinkService(),
    ),
  );
}

/// Mostrada só se o Firebase não puder ser iniciado (configuração ausente).
class _FirebaseErrorApp extends StatelessWidget {
  const _FirebaseErrorApp({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível iniciar o Firebase.',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(error, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
