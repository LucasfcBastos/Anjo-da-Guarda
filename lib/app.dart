import 'package:flutter/material.dart';

import 'controllers/caregiver_controller.dart';
import 'controllers/elder_sync_controller.dart';
import 'controllers/medication_controller.dart';
import 'controllers/safety_controller.dart';
import 'core/app_theme.dart';
import 'models/user_profile.dart';
import 'screens/alert_flow_screen.dart';
import 'screens/auth/auth_gate.dart';
import 'screens/caregiver/caregiver_home_screen.dart';
import 'screens/family_screen.dart';
import 'screens/home_screen.dart';
import 'screens/location_screen.dart';
import 'screens/medications_screen.dart';
import 'screens/sensor_screen.dart';
import 'services/auth_service.dart';
import 'services/link_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'widgets/elder_connection_panel.dart';

class AnjoDaGuardaApp extends StatefulWidget {
  const AnjoDaGuardaApp({
    super.key,
    required this.safety,
    required this.medications,
    required this.notifications,
    required this.location,
    required this.auth,
    required this.links,
  });

  final SafetyController safety;
  final MedicationController medications;
  final NotificationService notifications;
  final LocationService location;
  final AuthService auth;
  final LinkService links;

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
      // Login → interface do idoso ou do cuidador, conforme o perfil.
      home: AuthGate(
        auth: widget.auth,
        elderBuilder: (profile) => ElderRoot(
          profile: profile,
          safety: widget.safety,
          medications: widget.medications,
          notifications: widget.notifications,
          location: widget.location,
          auth: widget.auth,
          links: widget.links,
        ),
        caregiverBuilder: (profile) => CaregiverRoot(
          profile: profile,
          notifications: widget.notifications,
          auth: widget.auth,
          links: widget.links,
        ),
      ),
    );
  }
}

/// Interface do idoso: o app de monitoramento (abas) + sincronização
/// com os cuidadores no Firestore.
class ElderRoot extends StatefulWidget {
  const ElderRoot({
    super.key,
    required this.profile,
    required this.safety,
    required this.medications,
    required this.notifications,
    required this.location,
    required this.auth,
    required this.links,
  });

  final UserProfile profile;
  final SafetyController safety;
  final MedicationController medications;
  final NotificationService notifications;
  final LocationService location;
  final AuthService auth;
  final LinkService links;

  @override
  State<ElderRoot> createState() => _ElderRootState();
}

class _ElderRootState extends State<ElderRoot> {
  late final ElderSyncController _sync = ElderSyncController(
    profile: widget.profile,
    safety: widget.safety,
    location: widget.location,
    links: widget.links,
  );

  @override
  void initState() {
    super.initState();
    _sync.start();
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _sync.signOutCleanup();
    widget.safety.stopMonitoring();
    await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return MainShell(
      safety: widget.safety,
      medications: widget.medications,
      notifications: widget.notifications,
      location: widget.location,
      sync: _sync,
      onSignOut: _signOut,
    );
  }
}

/// Interface do cuidador: idosos vinculados, alertas e push.
class CaregiverRoot extends StatefulWidget {
  const CaregiverRoot({
    super.key,
    required this.profile,
    required this.notifications,
    required this.auth,
    required this.links,
  });

  final UserProfile profile;
  final NotificationService notifications;
  final AuthService auth;
  final LinkService links;

  @override
  State<CaregiverRoot> createState() => _CaregiverRootState();
}

class _CaregiverRootState extends State<CaregiverRoot> {
  late final CaregiverController _controller = CaregiverController(
    profile: widget.profile,
    links: widget.links,
    notifications: widget.notifications,
  );
  late final PushService _push = PushService(uid: widget.profile.uid);

  @override
  void initState() {
    super.initState();
    _controller.start();
    _setUpNotifications();
  }

  Future<void> _setUpNotifications() async {
    await widget.notifications.requestPermission();
    await _push.register();
  }

  @override
  void dispose() {
    _controller.dispose();
    _push.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _push.unregister();
    await widget.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return CaregiverHomeScreen(
      controller: _controller,
      push: _push,
      onSignOut: _signOut,
    );
  }
}

/// Estrutura principal do idoso com a barra de navegação inferior.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.safety,
    required this.medications,
    required this.notifications,
    required this.location,
    required this.sync,
    required this.onSignOut,
  });

  final SafetyController safety;
  final MedicationController medications;
  final NotificationService notifications;
  final LocationService location;
  final ElderSyncController sync;
  final Future<void> Function() onSignOut;

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
        connectionPanel: ElderConnectionPanel(
          sync: widget.sync,
          onOpenLocation: () => setState(() => _tab = 2),
          onOpenFamily: () => setState(() => _tab = 4),
        ),
      ),
      MedicationsScreen(
        controller: widget.medications,
        notifications: widget.notifications,
      ),
      LocationScreen(location: widget.location),
      SensorScreen(safety: widget.safety),
      FamilyScreen(
        sync: widget.sync,
        location: widget.location,
        onSignOut: widget.onSignOut,
      ),
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
          NavigationDestination(
            icon: Icon(Icons.family_restroom, size: 30),
            label: 'Família',
          ),
        ],
      ),
    );
  }
}
