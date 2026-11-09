import 'package:anjo_da_guarda/services/fall_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gera amostras a 50 Hz (a cada 20 ms), como o sensor real.
class _Feeder {
  _Feeder(this.detector);
  final FallDetector detector;
  DateTime time = DateTime(2026);

  /// Envia [count] amostras com aceleração vertical [z]; retorna se detectou queda.
  bool feed(double z, int count) {
    var detected = false;
    for (var i = 0; i < count; i++) {
      time = time.add(const Duration(milliseconds: 20));
      detected = detector.addSample(0, 0, z, time) || detected;
    }
    return detected;
  }
}

void main() {
  test('em repouso não detecta queda', () {
    final f = _Feeder(FallDetector());
    expect(f.feed(9.81, 500), isFalse);
  });

  test('impacto seguido de imobilidade é uma queda', () {
    final f = _Feeder(FallDetector());
    f.feed(9.81, 50);
    expect(f.feed(30, 3), isFalse); // impacto
    expect(f.detector.phase, FallPhase.checkingStillness);
    expect(f.feed(9.81, 150), isTrue); // 3 s parado
    expect(f.detector.phase, FallPhase.waitingForImpact);
  });

  test('impacto seguido de movimento contínuo não é queda', () {
    final f = _Feeder(FallDetector());
    f.feed(30, 3);
    // Pessoa continua andando: valores oscilando longe de 1 g.
    var detected = false;
    for (var i = 0; i < 100; i++) {
      detected = f.feed(i.isEven ? 14 : 5, 3) || detected;
    }
    expect(detected, isFalse);
    expect(f.detector.phase, FallPhase.waitingForImpact);
  });

  test('pouco tempo parado após o impacto ainda não confirma', () {
    final f = _Feeder(FallDetector());
    f.feed(30, 3);
    expect(f.feed(9.81, 60), isFalse); // ~1,2 s, menos que 0,5 + 2 s
  });

  test('magnitude combina os três eixos', () {
    expect(FallDetector.magnitude(3, 4, 0), 5);
  });
}
