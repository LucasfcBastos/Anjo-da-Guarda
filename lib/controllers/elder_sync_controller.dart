import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../models/care_link.dart';
import '../models/elder_status.dart';
import '../models/emergency_alert.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/link_service.dart';
import '../services/location_service.dart';
import 'safety_controller.dart';

enum GpsStatus {
  starting,
  active,
  serviceDisabled,
  denied,
  deniedForever,
  error,
}

/// Lado do idoso na nuvem:
/// - envia status do monitoramento e localização para `elders/{uid}`;
/// - transforma quedas e pedidos de ajuda em `elders/{uid}/alerts`;
/// - acompanha códigos e vínculos com cuidadores.
///
/// Gravações no Firestore ficam numa fila local quando não há internet
/// e são enviadas sozinhas quando a conexão volta.
class ElderSyncController extends ChangeNotifier with WidgetsBindingObserver {
  ElderSyncController({
    required this.profile,
    required this._safety,
    required this._location,
    required this._links,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Intervalo mínimo entre envios de localização (economiza bateria e cota).
  static const uploadInterval = Duration(seconds: 30);

  /// Sinal de vida enviado mesmo sem mudança de posição.
  static const heartbeatInterval = Duration(minutes: 5);

  final UserProfile profile;
  final SafetyController _safety;
  final LocationService _location;
  final LinkService _links;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _statusRef =>
      _db.collection('elders').doc(profile.uid);
  CollectionReference<Map<String, dynamic>> get _alertsRef =>
      _statusRef.collection('alerts');

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _statusSub;
  StreamSubscription<List<CareLink>>? _linksSub;
  StreamSubscription<List<LinkCode>>? _codesSub;
  Timer? _heartbeat;
  Timer? _gpsRetry;
  Timer? _codeExpiry;
  bool _started = false;
  bool _disposed = false;

  // --- Estado exposto para as telas -----------------------------------------

  GpsStatus _gps = GpsStatus.starting;
  String? _gpsMessage;
  LocationIssue? _gpsIssue;
  Position? _lastPosition;
  DateTime? _lastUploadAt;
  bool _synced = false;
  String? _syncError;
  List<CareLink> _careLinks = [];
  String? _linksError;
  List<LinkCode> _codes = [];

  GpsStatus get gpsStatus => _gps;
  String? get gpsMessage => _gpsMessage;
  LocationIssue? get gpsIssue => _gpsIssue;
  Position? get lastPosition => _lastPosition;
  DateTime? get lastUploadAt => _lastUploadAt;

  /// Verdadeiro quando o servidor confirmou todas as gravações.
  bool get isSynced => _synced;
  String? get syncError => _syncError;
  String? get linksError => _linksError;

  List<CareLink> get activeCaregivers =>
      _careLinks.where((l) => l.isActive).toList();
  List<CareLink> get pendingRequests =>
      _careLinks.where((l) => !l.isActive).toList();

  /// Código ainda válido mais recente, se houver.
  LinkCode? get currentCode {
    final now = DateTime.now();
    final valid = _codes.where((c) => c.isValidAt(now)).toList()
      ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt));
    return valid.isEmpty ? null : valid.first;
  }

  // --- Ciclo de vida ----------------------------------------------------------

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    _lastState = _safety.state;
    _lastMonitoring = _safety.isMonitoring;
    _lastSensorError = _safety.sensorError;
    _safety.addListener(_onSafetyChanged);

    _writeStatus({'name': profile.name, 'signedIn': true});
    _statusSub = _statusRef
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) => _set(() {
            _synced =
                !snap.metadata.hasPendingWrites && !snap.metadata.isFromCache;
          }),
          onError: (Object e) => _set(() => _syncError = authErrorMessage(e)),
        );
    _linksSub = _links
        .linksOfElder(profile.uid)
        .listen(
          (links) => _set(() {
            _careLinks = links;
            _linksError = null;
          }),
          onError: (Object e) => _set(() => _linksError = authErrorMessage(e)),
        );
    _codesSub = _links.codesOf(profile.uid).listen((codes) {
      _set(() => _codes = codes);
      _scheduleCodeExpiry();
    }, onError: (Object e) => debugPrint('Códigos: $e'));
    _heartbeat = Timer.periodic(heartbeatInterval, (_) => _writeStatus());

    startLocation();
  }

  /// Ao sair da conta: avisa os cuidadores e para de enviar dados.
  Future<void> signOutCleanup() async {
    try {
      await _statusRef
          .set({
            'signedIn': false,
            'monitoring': false,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Não foi possível avisar a saída: $e');
    }
    _stopAll();
  }

  void _stopAll() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _safety.removeListener(_onSafetyChanged);
    _positionSub?.cancel();
    _statusSub?.cancel();
    _linksSub?.cancel();
    _codesSub?.cancel();
    _heartbeat?.cancel();
    _gpsRetry?.cancel();
    _codeExpiry?.cancel();
  }

  @override
  void dispose() {
    _stopAll();
    _disposed = true;
    super.dispose();
  }

  /// Ao voltar para o app (ex.: depois de liberar a permissão
  /// nas configurações), tenta religar o GPS.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_gps != GpsStatus.active) startLocation();
      _writeStatus();
    }
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  // --- Status e localização ---------------------------------------------------

  void _writeStatus([Map<String, dynamic> extra = const {}]) {
    final data = <String, dynamic>{
      'monitoring': _safety.isMonitoring,
      'sensorError': _safety.sensorError,
      'safetyState': _safety.state.name,
      'gpsStatus': _gps.name,
      'gpsMessage': _gpsMessage,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'lastSeen': FieldValue.serverTimestamp(),
      ...extra,
    };
    // Sem await: offline, a gravação fica na fila e o Future só termina
    // quando o servidor confirmar.
    _statusRef.set(data, SetOptions(merge: true)).catchError((Object e) {
      _set(() => _syncError = authErrorMessage(e));
    });
  }

  Future<void> startLocation() async {
    _positionSub?.cancel();
    _positionSub = null;
    _gpsRetry?.cancel();
    _set(() {
      _gps = GpsStatus.starting;
      _gpsMessage = null;
      _gpsIssue = null;
    });
    try {
      await _location.ensureReady();
    } on LocationException catch (e) {
      _onGpsError(e);
      return;
    } catch (e) {
      _onGpsError(
        LocationException(
          LocationIssue.unavailable,
          'Erro ao acessar o GPS: $e',
        ),
      );
      return;
    }
    if (!_started) return;
    _positionSub = _location.trackPositions().listen(
      _onPosition,
      onError: (Object e) => _onGpsError(
        e is LocationException
            ? e
            : LocationException(LocationIssue.unavailable, '$e'),
      ),
      cancelOnError: true,
    );
  }

  void _onGpsError(LocationException e) {
    _positionSub?.cancel();
    _positionSub = null;
    _set(() {
      _gps = switch (e.issue) {
        LocationIssue.serviceDisabled => GpsStatus.serviceDisabled,
        LocationIssue.denied => GpsStatus.denied,
        LocationIssue.deniedForever => GpsStatus.deniedForever,
        LocationIssue.unavailable => GpsStatus.error,
      };
      _gpsMessage = e.message;
      _gpsIssue = e.issue;
    });
    _writeStatus();
    // GPS desligado ou falha passageira: tenta de novo em 1 minuto.
    // Permissão negada só muda quando a pessoa libera nas configurações.
    if (e.issue == LocationIssue.serviceDisabled ||
        e.issue == LocationIssue.unavailable) {
      _gpsRetry = Timer(const Duration(minutes: 1), startLocation);
    }
  }

  void _onPosition(Position p) {
    final wasActive = _gps == GpsStatus.active;
    _set(() {
      _lastPosition = p;
      _gps = GpsStatus.active;
      _gpsMessage = null;
      _gpsIssue = null;
    });
    final now = DateTime.now();
    final due =
        _lastUploadAt == null ||
        now.difference(_lastUploadAt!) >= uploadInterval ||
        !wasActive;
    if (!due) return;
    _lastUploadAt = now;
    _writeStatus({'location': _locationOf(p).toMap()});
  }

  SharedLocation _locationOf(Position p) => SharedLocation(
    lat: p.latitude,
    lng: p.longitude,
    accuracy: p.accuracy,
    at: p.timestamp,
  );

  // --- Quedas e emergências ---------------------------------------------------

  SafetyState _lastState = SafetyState.idle;
  bool _lastMonitoring = false;
  String? _lastSensorError;
  DocumentReference<Map<String, dynamic>>? _currentAlert;
  EmergencyAlert? _lastAlertData;

  void _onSafetyChanged() {
    final state = _safety.state;
    final previous = _lastState;
    final statusChanged =
        state != previous ||
        _safety.isMonitoring != _lastMonitoring ||
        _safety.sensorError != _lastSensorError;
    _lastState = state;
    _lastMonitoring = _safety.isMonitoring;
    _lastSensorError = _safety.sensorError;

    if (state != previous) _onTransition(previous, state);
    _syncAlertLocation();
    if (statusChanged) _writeStatus();
  }

  void _onTransition(SafetyState from, SafetyState to) {
    final now = DateTime.now();
    switch ((from, to)) {
      case (SafetyState.idle, SafetyState.awaitingConfirmation):
        _createAlert({
          'type': 'fall',
          'status': 'awaiting',
          'deadline': Timestamp.fromDate(
            now.add(const Duration(seconds: SafetyController.countdownSeconds)),
          ),
        });
      case (SafetyState.idle, SafetyState.emergency):
        _createAlert({
          'type': 'manual',
          'status': 'emergency',
          'emergencyAt': FieldValue.serverTimestamp(),
        });
      case (SafetyState.awaitingConfirmation, SafetyState.emergency):
        _updateAlert({
          'status': 'emergency',
          'emergencyAt': FieldValue.serverTimestamp(),
        });
      case (SafetyState.awaitingConfirmation, SafetyState.idle):
        _updateAlert({
          'status': 'safe',
          'safeAt': FieldValue.serverTimestamp(),
        });
        _currentAlert = null;
      case (SafetyState.emergency, SafetyState.idle):
        _updateAlert({
          'status': 'resolved',
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': profile.uid,
          'resolvedByName': profile.name,
        });
        _currentAlert = null;
      default:
        break;
    }
  }

  void _createAlert(Map<String, dynamic> data) {
    _lastAlertData = null;
    final ref = _alertsRef.doc();
    _currentAlert = ref;
    ref
        .set({
          ...data,
          'elderName': profile.name,
          'createdAt': FieldValue.serverTimestamp(),
          'clientCreatedAt': Timestamp.now(),
          if (_lastPosition != null)
            'location': _locationOf(_lastPosition!).toMap(),
        })
        .catchError((Object e) {
          _set(() => _syncError = authErrorMessage(e));
        });
  }

  void _updateAlert(Map<String, dynamic> data) {
    final ref = _currentAlert;
    if (ref == null) return;
    ref.update(data).catchError((Object e) {
      _set(() => _syncError = authErrorMessage(e));
    });
  }

  /// O alerta de emergência busca o GPS na hora; envia o resultado.
  void _syncAlertLocation() {
    final alert = _safety.alert;
    if (alert == null || identical(alert, _lastAlertData)) return;
    final previous = _lastAlertData;
    _lastAlertData = alert;
    final position = alert.position;
    if (position != null && !identical(position, previous?.position)) {
      final location = _locationOf(position).toMap();
      _updateAlert({'location': location, 'locationError': null});
      _writeStatus({'location': location});
    } else if (alert.locationError != null &&
        alert.locationError != previous?.locationError) {
      _updateAlert({'locationError': alert.locationError});
    }
  }

  // --- Vinculação ---------------------------------------------------------------

  Future<LinkCode> generateCode() => _links.createCode(profile);

  Future<void> approve(CareLink link) => _links.approve(link);

  Future<void> remove(CareLink link) => _links.remove(link);

  void _scheduleCodeExpiry() {
    _codeExpiry?.cancel();
    final code = currentCode;
    if (code == null) return;
    final wait = code.expiresAt.difference(DateTime.now());
    _codeExpiry = Timer(wait + const Duration(seconds: 1), () => _set(() {}));
  }
}
