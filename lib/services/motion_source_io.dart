import 'package:sensors_plus/sensors_plus.dart';

/// No app instalado não há pedido de permissão para o acelerômetro.
const bool motionPermissionRequired = false;

Future<bool> requestMotionPermission() async => true;

Stream<AccelerometerEvent> motionEvents() => accelerometerEventStream(
  samplingPeriod: SensorInterval.gameInterval, // ~50 Hz
);
