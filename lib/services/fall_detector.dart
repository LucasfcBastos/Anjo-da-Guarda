import 'dart:math';

/// Fases do algoritmo de detecção de queda.
enum FallPhase {
  /// Aguardando um pico de aceleração.
  waitingForImpact,

  /// Houve um pico; verificando se o aparelho ficou parado depois.
  checkingStillness,
}

/// Detecta uma possível queda em duas etapas:
///
/// 1. **Impacto**: a aceleração total passa de [impactThreshold]
///    (≈ 2,5 g). Em repouso o valor é ≈ 9,8 m/s² (só a gravidade).
/// 2. **Imobilidade**: depois do impacto, a aceleração fica perto de 1 g
///    (variação menor que [stillnessTolerance]) por [stillnessDuration].
///    Uma pessoa caída tende a ficar parada; quem só esbarrou o celular
///    continua se mexendo.
///
/// A classe não depende do Flutter: recebe amostras e responde se houve queda.
/// Isso facilita testar o algoritmo com testes unitários.
class FallDetector {
  FallDetector({
    this.impactThreshold = 25.0,
    this.stillnessTolerance = 1.5,
    this.settleTime = const Duration(milliseconds: 500),
    this.stillnessDuration = const Duration(seconds: 2),
    this.maxWaitForStillness = const Duration(seconds: 4),
  });

  static const double gravity = 9.81;

  final double impactThreshold;
  final double stillnessTolerance;

  /// Tempo ignorado logo após o impacto (o aparelho ainda quica/balança).
  final Duration settleTime;
  final Duration stillnessDuration;

  /// Se não ficar parado dentro deste tempo, o impacto é descartado.
  final Duration maxWaitForStillness;

  FallPhase _phase = FallPhase.waitingForImpact;
  DateTime? _impactAt;
  DateTime? _stillSince;
  double _peak = 0;

  FallPhase get phase => _phase;

  /// Maior aceleração registrada no último impacto.
  double get lastPeak => _peak;

  static double magnitude(double x, double y, double z) =>
      sqrt(x * x + y * y + z * z);

  /// Processa uma leitura do acelerômetro.
  /// Retorna `true` quando uma possível queda é confirmada.
  bool addSample(double x, double y, double z, DateTime time) {
    final m = magnitude(x, y, z);

    if (_phase == FallPhase.waitingForImpact) {
      if (m >= impactThreshold) _startImpact(m, time);
      return false;
    }

    // Fase de verificação de imobilidade.
    final sinceImpact = time.difference(_impactAt!);

    if (m >= impactThreshold) {
      // Novo pico (ex.: o corpo quicou): recomeça a contagem a partir dele.
      _startImpact(max(m, _peak), time);
      return false;
    }
    if (sinceImpact < settleTime) return false;

    final isStill = (m - gravity).abs() <= stillnessTolerance;
    if (isStill) {
      _stillSince ??= time;
      if (time.difference(_stillSince!) >= stillnessDuration) {
        reset();
        return true;
      }
    } else {
      _stillSince = null;
      if (sinceImpact > maxWaitForStillness) reset();
    }
    return false;
  }

  void _startImpact(double peak, DateTime time) {
    _phase = FallPhase.checkingStillness;
    _impactAt = time;
    _stillSince = null;
    _peak = peak;
  }

  void reset() {
    _phase = FallPhase.waitingForImpact;
    _impactAt = null;
    _stillSince = null;
  }
}
