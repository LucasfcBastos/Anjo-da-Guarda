import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/emergency_alert.dart';
import '../services/fall_detector.dart';
import '../services/location_service.dart';
import '../services/motion_source.dart';
import '../services/notification_service.dart';

/// Leitura do acelerômetro exibida na tela.
class SensorReading {
  const SensorReading(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
  double get magnitude => FallDetector.magnitude(x, y, z);
}

enum SafetyState {
  /// Tudo normal.
  idle,

  /// Queda detectada: perguntando "Você está bem?" com contagem regressiva.
  awaitingConfirmation,

  /// Sem resposta (ou pedido manual): alerta de emergência ativo.
  emergency,
}

/// Liga os recursos do app:
/// acelerômetro → detecção de queda → pergunta com 30 s → alerta com GPS.
class SafetyController extends ChangeNotifier {
  SafetyController({
    required this._notifications,
    required this._location,
    FallDetector? detector,
  }) : detector = detector ?? FallDetector() {
    _notifications.onAction = _onNotificationAction;
  }

  static const int countdownSeconds = 30;
  static const int historySize = 150; // ~3 s de leituras para o gráfico

  final NotificationService _notifications;
  final LocationService _location;
  final FallDetector detector;

  // --- Acelerômetro ---------------------------------------------------------

  StreamSubscription<AccelerometerEvent>? _sensorSub;
  bool _monitoring = false;
  String? _sensorError;

  /// Atualizado a cada leitura. Fica separado do [notifyListeners] para
  /// redesenhar só os widgets do sensor (~50 vezes por segundo).
  final ValueNotifier<SensorReading?> reading = ValueNotifier(null);
  final List<double> magnitudeHistory = [];

  bool get isMonitoring => _monitoring;
  String? get sensorError => _sensorError;

  void startMonitoring() {
    if (_monitoring) return;
    _sensorError = null;
    _monitoring = true;
    if (motionPermissionRequired) {
      // Navegador do iPhone: a permissão é pedida já, dentro do toque no
      // botão; ao abrir o app (sem toque) o iOS recusa e pedimos o toque.
      requestMotionPermission().then((granted) {
        if (!_monitoring || _sensorSub != null) return;
        if (granted) {
          _listenAccelerometer();
        } else {
          _sensorError =
              'Toque no botão para ligar o sensor e permita o acesso a '
              '"Movimento e orientação".';
          stopMonitoring();
        }
      });
    } else {
      _listenAccelerometer();
    }
    notifyListeners();
  }

  void _listenAccelerometer() {
    _sensorSub = motionEvents().listen(
      _onAccelerometer,
      onError: (Object e) {
        _sensorError = e is MotionUnavailable
            ? e.message
            : 'Acelerômetro indisponível neste aparelho.';
        stopMonitoring();
      },
      cancelOnError: true,
    );
  }

  void stopMonitoring() {
    _sensorSub?.cancel();
    _sensorSub = null;
    _monitoring = false;
    detector.reset();
    notifyListeners();
  }

  void _onAccelerometer(AccelerometerEvent e) {
    final current = SensorReading(e.x, e.y, e.z);
    magnitudeHistory.add(current.magnitude);
    if (magnitudeHistory.length > historySize) magnitudeHistory.removeAt(0);
    reading.value = current;

    // Durante a pergunta ou o alerta não procuramos novas quedas.
    if (_state != SafetyState.idle) return;
    if (detector.addSample(e.x, e.y, e.z, e.timestamp)) {
      onFallDetected();
    }
  }

  // --- Fluxo de queda -------------------------------------------------------

  SafetyState _state = SafetyState.idle;
  int _secondsLeft = countdownSeconds;
  Timer? _countdown;
  EmergencyAlert? _alert;

  SafetyState get state => _state;
  int get secondsLeft => _secondsLeft;
  EmergencyAlert? get alert => _alert;

  /// Passo 1: queda detectada → pergunta "Você está bem?" por 30 s.
  void onFallDetected() {
    if (_state != SafetyState.idle) return;
    _state = SafetyState.awaitingConfirmation;
    _secondsLeft = countdownSeconds;
    _notifications.showFallCheck(countdownSeconds);

    // A contagem usa um horário-limite (e não só "menos 1 por segundo"):
    // se o sistema pausar o app em segundo plano (comum no iOS), ao voltar
    // o tempo continua certo. A notificação agendada é a reserva caso o app
    // fique pausado até o fim.
    final deadline = clock.now().add(const Duration(seconds: countdownSeconds));
    _notifications.scheduleEmergencyBackup(
      deadline.add(const Duration(seconds: 2)),
    );
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = deadline.difference(clock.now());
      _secondsLeft = (remaining.inMilliseconds / 1000).ceil().clamp(
        0,
        countdownSeconds,
      );
      if (_secondsLeft <= 0) {
        // Passo 2b: ninguém respondeu → emergência.
        triggerEmergency(EmergencyReason.fallWithoutResponse);
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Passo 2a: o usuário respondeu que está bem.
  void confirmSafe() {
    if (_state != SafetyState.awaitingConfirmation) return;
    _countdown?.cancel();
    _notifications.cancel(NotificationService.fallCheckId);
    _notifications.cancel(NotificationService.emergencyId); // reserva
    _state = SafetyState.idle;
    notifyListeners();
  }

  /// Passo 3: alerta de emergência com a localização GPS.
  Future<void> triggerEmergency(EmergencyReason reason) async {
    if (_state == SafetyState.emergency) return;
    _countdown?.cancel();
    _notifications.cancel(NotificationService.fallCheckId);
    _notifications.cancel(NotificationService.emergencyId); // reserva
    _state = SafetyState.emergency;
    _alert = EmergencyAlert(
      reason: reason,
      createdAt: DateTime.now(),
      isLoadingLocation: true,
    );
    notifyListeners();
    await refreshAlertLocation();
  }

  /// Busca (ou busca de novo) a posição GPS para o alerta atual.
  Future<void> refreshAlertLocation() async {
    final current = _alert;
    if (current == null) return;
    _alert = current.copyWith(isLoadingLocation: true);
    notifyListeners();

    EmergencyAlert updated;
    try {
      final position = await _location.getCurrentPosition();
      updated = EmergencyAlert(
        reason: current.reason,
        createdAt: current.createdAt,
        position: position,
      );
    } on LocationException catch (e) {
      updated = current.copyWith(
        isLoadingLocation: false,
        locationError: e.message,
      );
    }
    // O alerta pode ter sido encerrado enquanto o GPS respondia.
    if (_alert?.createdAt != current.createdAt) return;
    _alert = updated;
    await _notifications.showEmergency(updated);
    notifyListeners();
  }

  /// Encerra o alerta (ajuda chegou / alarme falso).
  void resolveEmergency() {
    _notifications.cancel(NotificationService.emergencyId);
    _state = SafetyState.idle;
    _alert = null;
    notifyListeners();
  }

  void _onNotificationAction(String? actionId) {
    if (actionId == NotificationService.actionImOk) confirmSafe();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _countdown?.cancel();
    reading.dispose();
    super.dispose();
  }
}
