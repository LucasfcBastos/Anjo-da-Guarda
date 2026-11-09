import 'package:cloud_firestore/cloud_firestore.dart';

import 'elder_status.dart';

/// Status gravado em `elders/{uid}/alerts/{id}`.
enum AlertStatus {
  /// Queda detectada; esperando o idoso responder "Você está bem?".
  awaiting,

  /// Sem resposta no prazo, ou pedido de ajuda manual.
  emergency,

  /// O idoso respondeu que está bem.
  safe,

  /// Encerrado (pelo idoso ou marcado como atendido pelo cuidador).
  resolved;

  static AlertStatus fromId(Object? id) => values.firstWhere(
    (s) => s.name == id,
    orElse: () => AlertStatus.emergency,
  );
}

/// Situação real de um alerta, considerando o horário atual.
enum AlertSituation {
  possibleFall,

  /// O prazo de 30 s passou e o celular do idoso não confirmou nada
  /// (pode estar sem internet, desligado ou com o app pausado).
  unanswered,
  emergency,
  safe,
  resolved;

  bool get isActive =>
      this == possibleFall || this == unanswered || this == emergency;

  bool get isEmergency => this == unanswered || this == emergency;
}

class AlertRecord {
  const AlertRecord({
    required this.id,
    required this.elderId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.deadline,
    this.location,
    this.locationError,
    this.resolvedByName,
    this.closedAt,
  });

  /// Tolerância para atrasos de rede antes de considerar "sem resposta".
  static const grace = Duration(seconds: 10);

  final String id;
  final String elderId;

  /// "fall" (queda detectada) ou "manual" (botão PEDIR AJUDA).
  final String type;
  final AlertStatus status;
  final DateTime createdAt;
  final DateTime? deadline;
  final SharedLocation? location;
  final String? locationError;
  final String? resolvedByName;
  final DateTime? closedAt;

  bool get isFall => type == 'fall';

  String get typeLabel => isFall ? 'Possível queda' : 'Pedido de ajuda';

  AlertSituation situationAt(DateTime now) => switch (status) {
    AlertStatus.awaiting =>
      deadline != null && now.isAfter(deadline!.add(grace))
          ? AlertSituation.unanswered
          : AlertSituation.possibleFall,
    AlertStatus.emergency => AlertSituation.emergency,
    AlertStatus.safe => AlertSituation.safe,
    AlertStatus.resolved => AlertSituation.resolved,
  };

  factory AlertRecord.fromDoc(
    String elderId,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? const {};
    DateTime? time(String key) => (d[key] as Timestamp?)?.toDate();
    return AlertRecord(
      id: doc.id,
      elderId: elderId,
      type: d['type'] as String? ?? 'fall',
      status: AlertStatus.fromId(d['status']),
      // createdAt é a hora do servidor; enquanto não chega, usa a do celular.
      createdAt: time('createdAt') ?? time('clientCreatedAt') ?? DateTime.now(),
      deadline: time('deadline'),
      location: SharedLocation.fromMap(d['location']),
      locationError: d['locationError'] as String?,
      resolvedByName: d['resolvedByName'] as String?,
      closedAt: time('resolvedAt') ?? time('safeAt'),
    );
  }
}

/// Situação geral do idoso mostrada ao cuidador.
enum ElderSituation {
  emergency,
  possibleFall,
  ok,
  paused,
  stale,
  signedOut,
  unknown,
}

/// Sem notícias do celular do idoso há mais que isso → "sem atualização".
const staleAfter = Duration(minutes: 15);

ElderSituation elderSituation(
  ElderStatus? status,
  List<AlertRecord> alerts,
  DateTime now,
) {
  final situations = alerts.map((a) => a.situationAt(now));
  if (situations.any((s) => s.isEmergency)) return ElderSituation.emergency;
  if (situations.contains(AlertSituation.possibleFall)) {
    return ElderSituation.possibleFall;
  }
  if (status == null) return ElderSituation.unknown;
  if (!status.signedIn) return ElderSituation.signedOut;
  final lastSeen = status.lastSeen;
  if (lastSeen == null || now.difference(lastSeen) > staleAfter) {
    return ElderSituation.stale;
  }
  if (!status.monitoring) return ElderSituation.paused;
  return ElderSituation.ok;
}
