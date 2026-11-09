import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Motivos pelos quais a localização pode falhar.
enum LocationIssue { serviceDisabled, denied, deniedForever, unavailable }

class LocationException implements Exception {
  const LocationException(this.issue, this.message);
  final LocationIssue issue;
  final String message;

  @override
  String toString() => message;
}

/// Obtém a posição real do GPS, cuidando de permissões e erros.
class LocationService {
  /// Pede a permissão logo ao abrir o app, para que o diálogo
  /// não apareça só no meio de uma emergência.
  Future<void> requestPermissionIfNeeded() async {
    if (await Geolocator.checkPermission() == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationIssue.serviceDisabled,
        'O GPS do celular está desligado. Ative a localização.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(
        LocationIssue.denied,
        'Permissão de localização negada.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationIssue.deniedForever,
        'Permissão de localização bloqueada. Libere nas configurações do app.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      // Sem sinal de satélite a tempo: usa a última posição real conhecida.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationException(
        LocationIssue.unavailable,
        'Não foi possível obter o sinal do GPS. Tente em local aberto.',
      );
    } catch (e) {
      throw LocationException(
        LocationIssue.unavailable,
        'Erro ao obter localização: $e',
      );
    }
  }

  /// Abre a tela de configuração adequada para resolver o problema.
  Future<void> openSettingsFor(LocationIssue issue) async {
    if (issue == LocationIssue.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
