import 'package:flutter/material.dart';

import 'controllers/medication_controller.dart';
import 'controllers/safety_controller.dart';
import 'core/app_theme.dart';
import 'screens/alert_flow_screen.dart';
import 'screens/home_screen.dart';
import 'screens/location_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/sensor_screen.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';

class AnjoDaGuardaApp extends StatefulWidget {
  const AnjoDaGuardaApp({
    super.key,
    required this.safety,
    required this.medications,
    required this.notifications,
    required this.location,
  });

  final SafetyController safety;
  final MedicationController medications;
  final NotificationService notifications;
  final LocationService location;

  @override
  State<AnjoDaGuardaApp> createState() => _AnjoDaGuardaAppState();
}

class _AnjoDaGuardaAppState extends State<AnjoDaGuardaApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _alertScreenOpen = false;

  @override
  void initState() {
    super.initState();
    widget.safety.addListener(_openAlertScreenIfNeeded);
  }

  @override
  void dispose() {
    widget.safety.removeListener(_openAlertScreenIfNeeded);
    super.dispose();
  }

  /// Queda detectada ou emergência → abre a tela de alerta,
  /// esteja o usuário em qualquer aba.
  void _openAlertScreenIfNeeded() {
    if (widget.safety.state == SafetyState.idle || _alertScreenOpen) return;
    _alertScreenOpen = true;
    _navigatorKey.currentState
        ?.push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => AlertFlowScreen(safety: widget.safety),
          ),
        )
        .whenComplete(() => _alertScreenOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anjo da Guarda',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light,
      home: MainShell(
        safety: widget.safety,
        medications: widget.medications,
        notifications: widget.notifications,
        location: widget.location,
      ),
    );
  }
}

/// Estrutura principal com a barra de navegação inferior.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.safety,
    required this.medications,
    required this.notifications,
    required this.location,
  });

  final SafetyController safety;
  final MedicationController medications;
  final NotificationService notifications;
  final LocationService location;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.safety.startMonitoring();
    _requestPermissions();
  }

  /// Notificações e GPS são pedidos ao abrir o app (um diálogo por vez).
  Future<void> _requestPermissions() async {
    await widget.notifications.requestPermission();
    await widget.location.requestPermissionIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        safety: widget.safety,
        medications: widget.medications,
        onOpenTab: (i) => setState(() => _tab = i),
      ),
      MedicationsScreen(
        controller: widget.medications,
        notifications: widget.notifications,
      ),
      LocationScreen(location: widget.location),
      SensorScreen(safety: widget.safety),
    ];

    return Scaffold(
      // IndexedStack mantém o estado de cada aba ao trocar.
      body: IndexedStack(index: _tab, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home, size: 30),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication, size: 30),
            label: 'Remédios',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on, size: 30),
            label: 'Local',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors, size: 30),
            label: 'Sensor',
          ),
        ],
      ),
    );
  }
}
