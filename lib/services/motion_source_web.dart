import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:sensors_plus/sensors_plus.dart';
import 'package:web/web.dart' as web;

import 'motion_source.dart';

/// Sem leitura nesse tempo → o navegador não fornece o sensor.
const _noDataTimeout = Duration(seconds: 4);

JSObject? get _deviceMotionClass =>
    globalContext.getProperty<JSObject?>('DeviceMotionEvent'.toJS);

/// O Safari do iPhone exige pedir permissão num toque do usuário.
bool get motionPermissionRequired =>
    _deviceMotionClass?.has('requestPermission') ?? false;

bool _granted = false;

/// Precisa ser chamado direto no toque de um botão (o iOS exige um gesto).
Future<bool> requestMotionPermission() async {
  if (!motionPermissionRequired || _granted) return true;
  try {
    // A chamada ao JavaScript acontece já, ainda dentro do toque.
    final promise = _deviceMotionClass!.callMethod<JSPromise<JSString>>(
      'requestPermission'.toJS,
    );
    final result = (await promise.toDart).toDart;
    _granted = result == 'granted';
  } catch (_) {
    // Chamado fora de um toque (ex.: ao abrir o app) ou recusado.
    _granted = false;
  }
  return _granted;
}

Stream<AccelerometerEvent> motionEvents() {
  late StreamController<AccelerometerEvent> controller;
  JSFunction? listener;
  Timer? noData;

  void stop() {
    noData?.cancel();
    if (listener != null) {
      web.window.removeEventListener('devicemotion', listener);
      listener = null;
    }
  }

  controller = StreamController<AccelerometerEvent>(
    onListen: () {
      listener = ((web.Event event) {
        final a = (event as web.DeviceMotionEvent).accelerationIncludingGravity;
        final x = a?.x, y = a?.y, z = a?.z;
        // Computadores disparam o evento sem valores: não há sensor.
        if (x == null || y == null || z == null) return;
        noData?.cancel();
        controller.add(AccelerometerEvent(x, y, z, DateTime.now()));
      }).toJS;
      web.window.addEventListener('devicemotion', listener);
      noData = Timer(_noDataTimeout, () {
        controller.addError(
          MotionUnavailable(
            motionPermissionRequired && !_granted
                ? 'Toque no botão para ligar o sensor e permita o acesso a '
                      '"Movimento e orientação".'
                : 'Este navegador não fornece o sensor de movimento. '
                      'Use o celular (Safari no iPhone, Chrome no Android) '
                      'ou o app instalado.',
          ),
        );
      });
    },
    onCancel: stop,
  );
  return controller.stream;
}
