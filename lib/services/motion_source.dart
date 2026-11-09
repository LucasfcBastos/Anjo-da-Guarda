/// Leituras do acelerômetro para a detecção de queda.
/// - Android/iOS (app instalado): sensors_plus, como sempre.
/// - Navegador: evento `devicemotion` (Safari do iPhone e Chrome do
///   Android), que o sensors_plus não usa.
library;

export 'motion_source_io.dart'
    if (dart.library.js_interop) 'motion_source_web.dart';

/// Sensor de movimento indisponível, com a explicação para o usuário.
class MotionUnavailable implements Exception {
  const MotionUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}
