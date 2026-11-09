import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/alert_record.dart';
import '../models/care_link.dart';
import '../models/elder_status.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/link_service.dart';
import '../services/notification_service.dart';

/// Dados de um idoso acompanhado.
class ElderView {
  ElderView(this.link);

  CareLink link;
  ElderStatus? status;
  List<AlertRecord> alerts = const [];
  String? error;
  bool loaded = false;

  String get elderId => link.elderId;
  String get name =>
      (status?.name.isNotEmpty ?? false) ? status!.name : link.elderName;

  ElderSituation situationAt(DateTime now) =>
      elderSituation(status, alerts, now);
}

/// Lado do cuidador: lista de idosos vinculados com status, localização e
/// alertas em tempo real (Firestore). Enquanto o app está aberto (ou ainda
/// ativo em segundo plano), mostra notificações locais dos alertas.
class CaregiverController extends ChangeNotifier {
  CaregiverController({
    required this.profile,
    required this._links,
    required this._notifications,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  /// Quantos alertas recentes carregar por idoso (histórico).
  static const historySize = 30;

  final UserProfile profile;
  final LinkService _links;
  final NotificationService _notifications;
  final FirebaseFirestore _db;

  StreamSubscription<List<CareLink>>? _linksSub;
  final Map<String, ElderView> _elders = {};
  final Map<String, List<StreamSubscription<Object?>>> _elderSubs = {};
  List<CareLink> _pending = [];
  String? _error;
  bool _loading = true;
  Timer? _clock;
  bool _disposed = false;

  /// Alertas já notificados: "idAlerta:situação".
  final Set<String> _notified = {};

  List<ElderView> get elders {
    final now = DateTime.now();
    final list = _elders.values.toList()
      ..sort((a, b) {
        final bySituation = a
            .situationAt(now)
            .index
            .compareTo(b.situationAt(now).index);
        return bySituation != 0 ? bySituation : a.name.compareTo(b.name);
      });
    return list;
  }

  ElderView? elder(String elderId) => _elders[elderId];
  List<CareLink> get pendingLinks => _pending;
  String? get error => _error;
  bool get isLoading => _loading;

  void start() {
    _linksSub = _links
        .linksOfCaregiver(profile.uid)
        .listen(
          _onLinks,
          onError: (Object e) => _set(() {
            _error = authErrorMessage(e);
            _loading = false;
          }),
        );
    // Reavalia prazos ("sem resposta") e textos "há X min".
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkAlerts();
      _set(() {});
    });
  }

  void _set(VoidCallback change) {
    if (_disposed) return;
    change();
    notifyListeners();
  }

  void _onLinks(List<CareLink> links) {
    final active = {
      for (final l in links.where((l) => l.isActive)) l.elderId: l,
    };
    for (final id in _elders.keys.toList()) {
      if (!active.containsKey(id)) _unwatch(id);
    }
    for (final entry in active.entries) {
      final existing = _elders[entry.key];
      if (existing != null) {
        existing.link = entry.value;
      } else {
        _watch(entry.value);
      }
    }
    _set(() {
      _pending = links.where((l) => !l.isActive).toList();
      _error = null;
      _loading = false;
    });
  }

  void _watch(CareLink link) {
    final view = ElderView(link);
    _elders[link.elderId] = view;
    final elderRef = _db.collection('elders').doc(link.elderId);
    var firstAlerts = true;

    final statusSub = elderRef.snapshots().listen(
      (snap) => _set(() {
        final data = snap.data();
        view.status = data == null ? null : ElderStatus.fromMap(data);
        view.error = null;
      }),
      onError: (Object e) => _set(() => view.error = authErrorMessage(e)),
    );
    final alertsSub = elderRef
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .limit(historySize)
        .snapshots()
        .listen((snap) {
          view.alerts = snap.docs
              .map((d) => AlertRecord.fromDoc(link.elderId, d))
              .toList();
          view.loaded = true;
          view.error = null;
          if (firstAlerts) {
            firstAlerts = false;
            _seedNotified(view);
          }
          _checkAlerts();
          _set(() {});
        }, onError: (Object e) => _set(() => view.error = authErrorMessage(e)));
    _elderSubs[link.elderId] = [statusSub, alertsSub];
  }

  void _unwatch(String elderId) {
    for (final sub in _elderSubs.remove(elderId) ?? const []) {
      sub.cancel();
    }
    _elders.remove(elderId);
  }

  /// Ao abrir o app, só avisa sobre alertas ainda em andamento.
  void _seedNotified(ElderView view) {
    final now = DateTime.now();
    for (final a in view.alerts) {
      final situation = a.situationAt(now);
      if (!situation.isActive) _notified.add('${a.id}:${situation.name}');
    }
  }

  void _checkAlerts() {
    final now = DateTime.now();
    for (final view in _elders.values) {
      for (final a in view.alerts) {
        final situation = a.situationAt(now);
        final key = '${a.id}:${situation.name}';
        if (_notified.contains(key)) continue;
        // "Está bem" só interessa se o cuidador soube da possível queda.
        if (situation == AlertSituation.safe &&
            !_notified.contains(
              '${a.id}:${AlertSituation.possibleFall.name}',
            )) {
          _notified.add(key);
          continue;
        }
        if (situation == AlertSituation.resolved) {
          _notified.add(key);
          continue;
        }
        _notified.add(key);
        // Emergência e "sem resposta" usam a mesma tag do push do servidor.
        final tagStatus = situation.isEmergency ? 'emergency' : situation.name;
        _notify(view.name, a, situation, '${a.id}-$tagStatus');
      }
    }
  }

  void _notify(
    String name,
    AlertRecord a,
    AlertSituation situation,
    String tag,
  ) {
    final (title, body) = switch (situation) {
      AlertSituation.possibleFall => (
        'Possível queda: $name',
        'O celular de $name detectou uma possível queda. Aguardando '
            'resposta por até 30 segundos.',
      ),
      AlertSituation.unanswered => (
        'EMERGÊNCIA: $name não respondeu',
        '$name não confirmou que está bem após uma possível queda. '
            'Abra o app para ver a localização.',
      ),
      AlertSituation.emergency => (
        a.isFall
            ? 'EMERGÊNCIA: $name não respondeu'
            : 'EMERGÊNCIA: $name pediu ajuda',
        'Abra o app para ver a localização de $name.',
      ),
      AlertSituation.safe => (
        '$name está bem',
        '$name respondeu que está bem após a possível queda.',
      ),
      AlertSituation.resolved => ('', ''),
    };
    _notifications
        .showCaregiverAlert(
          tag: tag,
          title: title,
          body: body,
          urgent: situation.isEmergency,
        )
        .catchError((Object e) => debugPrint('Notificação: $e'));
  }

  // --- Ações -------------------------------------------------------------------

  Future<String> requestLink(String code) => _links.requestLink(profile, code);

  Future<void> cancelLink(CareLink link) => _links.remove(link);

  Future<void> resolveAlert(AlertRecord alert) => _db
      .collection('elders')
      .doc(alert.elderId)
      .collection('alerts')
      .doc(alert.id)
      .update({
        'status': 'resolved',
        'resolvedBy': profile.uid,
        'resolvedByName': profile.name,
        'resolvedAt': FieldValue.serverTimestamp(),
      });

  @override
  void dispose() {
    _disposed = true;
    _linksSub?.cancel();
    _clock?.cancel();
    for (final id in _elderSubs.keys.toList()) {
      _unwatch(id);
    }
    super.dispose();
  }
}
