import 'dart:async';
import 'dart:math';

import 'package:anjo_da_guarda/controllers/caregiver_controller.dart';
import 'package:anjo_da_guarda/controllers/elder_sync_controller.dart';
import 'package:anjo_da_guarda/controllers/safety_controller.dart';
import 'package:anjo_da_guarda/models/alert_record.dart';
import 'package:anjo_da_guarda/models/care_link.dart';
import 'package:anjo_da_guarda/models/elder_status.dart';
import 'package:anjo_da_guarda/models/emergency_alert.dart';
import 'package:anjo_da_guarda/models/user_profile.dart';
import 'package:anjo_da_guarda/services/link_service.dart';
import 'package:anjo_da_guarda/services/location_service.dart';
import 'package:anjo_da_guarda/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Substitutos: não há GPS nem notificações no computador.
class _FakeNotifications extends NotificationService {
  final caregiverAlerts = <String>[];
  @override
  Future<void> showFallCheck(int seconds) async {}
  @override
  Future<void> showEmergency(EmergencyAlert alert) async {}
  @override
  Future<void> scheduleEmergencyBackup(DateTime when) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> showCaregiverAlert({
    required String tag,
    required String title,
    required String body,
    required bool urgent,
  }) async => caregiverAlerts.add(title);
}

Position _position(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime.now(),
  accuracy: 8,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeLocation extends LocationService {
  final positions = StreamController<Position>.broadcast();
  @override
  Future<void> ensureReady() async {}
  @override
  Stream<Position> trackPositions() => positions.stream;
  @override
  Future<Position> getCurrentPosition() async => _position(-23.55, -46.63);
}

const elder = UserProfile(
  uid: 'idoso1',
  name: 'Ana',
  email: 'ana@teste.com',
  role: UserRole.elder,
);
const caregiver = UserProfile(
  uid: 'cuidador1',
  name: 'Bruno',
  email: 'bruno@teste.com',
  role: UserRole.caregiver,
);

/// Deixa os listeners do Firestore simulado processarem as mudanças.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('código de vinculação', () {
    test('tem 6 caracteres sem letras/números ambíguos', () {
      final random = Random(1);
      for (var i = 0; i < 200; i++) {
        final code = LinkService.generateCode(random);
        expect(LinkService.isWellFormed(code), isTrue, reason: code);
        expect(code, isNot(matches(RegExp('[IO01]'))));
      }
    });

    test('aceita minúsculas, espaço e hífen', () {
      expect(LinkService.normalize(' abc-23 4 '), 'ABC234');
      expect(LinkService.isWellFormed('ABC23'), isFalse);
      expect(LinkService.isWellFormed('ABC1O0'), isFalse);
    });
  });

  group('situação dos alertas', () {
    final now = DateTime(2026, 11, 9, 12);

    AlertRecord alert(AlertStatus status, {DateTime? deadline}) => AlertRecord(
      id: 'a',
      elderId: 'e',
      type: 'fall',
      status: status,
      createdAt: now.subtract(const Duration(seconds: 20)),
      deadline: deadline,
    );

    test('queda vira "sem resposta" quando o prazo passa', () {
      final a = alert(
        AlertStatus.awaiting,
        deadline: now.add(const Duration(seconds: 10)),
      );
      expect(a.situationAt(now), AlertSituation.possibleFall);
      expect(
        a.situationAt(now.add(const Duration(seconds: 25))),
        AlertSituation.unanswered,
      );
    });

    test('emergência tem prioridade sobre o resto', () {
      final status = ElderStatus.fromMap({
        'monitoring': true,
        'lastSeen': Timestamp.fromDate(now),
      });
      expect(elderSituation(status, [], now), ElderSituation.ok);
      expect(
        elderSituation(status, [alert(AlertStatus.emergency)], now),
        ElderSituation.emergency,
      );
      expect(
        elderSituation(status, [alert(AlertStatus.resolved)], now),
        ElderSituation.ok,
      );
    });

    test('sem notícias há mais de 15 minutos', () {
      final status = ElderStatus.fromMap({
        'monitoring': true,
        'lastSeen': Timestamp.fromDate(
          now.subtract(const Duration(minutes: 16)),
        ),
      });
      expect(elderSituation(status, [], now), ElderSituation.stale);
      expect(
        elderSituation(
          ElderStatus.fromMap({
            'monitoring': false,
            'lastSeen': Timestamp.fromDate(now),
          }),
          [],
          now,
        ),
        ElderSituation.paused,
      );
    });
  });

  group('fluxo idoso ↔ cuidador (Firestore simulado)', () {
    late FakeFirebaseFirestore db;
    late LinkService links;

    setUp(() {
      db = FakeFirebaseFirestore();
      links = LinkService(db: db);
    });

    test('código → pedido pendente → aprovação', () async {
      final code = await links.createCode(elder);
      final name = await links.requestLink(caregiver, code.code.toLowerCase());
      expect(name, 'Ana');

      var list = await links.linksOfElder(elder.uid).first;
      expect(list.single.status, LinkStatus.pending);
      expect(list.single.caregiverName, 'Bruno');

      await links.approve(list.single);
      list = await links.linksOfCaregiver(caregiver.uid).first;
      expect(list.single.isActive, isTrue);
    });

    test('código inexistente, expirado ou repetido é recusado', () async {
      await expectLater(
        links.requestLink(caregiver, 'ZZZ999'),
        throwsA(isA<LinkException>()),
      );

      await db.collection('linkCodes').doc('ABC234').set({
        'elderId': elder.uid,
        'elderName': 'Ana',
        'expiresAt': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });
      await expectLater(
        links.requestLink(caregiver, 'ABC234'),
        throwsA(
          isA<LinkException>().having(
            (e) => e.message,
            'msg',
            contains('expirou'),
          ),
        ),
      );

      final code = await links.createCode(elder);
      await links.requestLink(caregiver, code.code);
      await expectLater(
        links.requestLink(caregiver, code.code),
        throwsA(
          isA<LinkException>().having(
            (e) => e.message,
            'msg',
            contains('já enviado'),
          ),
        ),
      );
    });

    test('gerar código novo apaga o anterior', () async {
      final first = await links.createCode(elder);
      final second = await links.createCode(elder);
      final codes = await links.codesOf(elder.uid).first;
      expect(codes.map((c) => c.code), [second.code]);
      expect(first.code == second.code, isFalse);
    });

    test('queda no idoso aparece para o cuidador e gera notificação', () async {
      // Vínculo já aprovado.
      final code = await links.createCode(elder);
      await links.requestLink(caregiver, code.code);
      await links.approve((await links.linksOfElder(elder.uid).first).single);

      final notifications = _FakeNotifications();
      final location = _FakeLocation();
      final safety = SafetyController(
        notifications: notifications,
        location: location,
      );
      final sync = ElderSyncController(
        profile: elder,
        safety: safety,
        location: location,
        links: links,
        db: db,
      )..start();
      final care = CaregiverController(
        profile: caregiver,
        links: links,
        notifications: notifications,
        db: db,
      )..start();
      addTearDown(() {
        care.dispose();
        sync.dispose();
        safety.dispose();
        location.positions.close();
      });

      // Localização enviada pelo idoso (depois de o GPS ligar).
      await settle();
      location.positions.add(_position(-23.5, -46.6));
      await settle();
      expect(sync.gpsStatus, GpsStatus.active);
      expect(sync.activeCaregivers.single.caregiverName, 'Bruno');
      var view = care.elders.single;
      expect(view.status?.location?.lat, -23.5);
      expect(view.status?.lastSeen, isNotNull);

      // Queda detectada → cuidador vê "possível queda" e é avisado.
      safety.onFallDetected();
      await settle();
      view = care.elders.single;
      expect(view.alerts.single.status, AlertStatus.awaiting);
      expect(view.situationAt(DateTime.now()), ElderSituation.possibleFall);
      expect(notifications.caregiverAlerts.last, contains('Possível queda'));

      // Idoso responde "Estou bem".
      safety.confirmSafe();
      await settle();
      expect(care.elders.single.alerts.single.status, AlertStatus.safe);
      expect(notifications.caregiverAlerts.last, contains('está bem'));

      // Pedido de ajuda → emergência com a localização do GPS.
      await safety.triggerEmergency(EmergencyReason.manualRequest);
      await settle();
      final emergency = care.elders.single.alerts.firstWhere(
        (a) => a.type == 'manual',
      );
      expect(emergency.status, AlertStatus.emergency);
      expect(emergency.location?.lat, -23.55);
      expect(notifications.caregiverAlerts.last, contains('pediu ajuda'));

      // Cuidador marca como atendido.
      await care.resolveAlert(emergency);
      await settle();
      expect(
        care.elders.single.alerts
            .firstWhere((a) => a.id == emergency.id)
            .status,
        AlertStatus.resolved,
      );
    });

    test('queda sem resposta vira emergência para o cuidador', () async {
      final notifications = _FakeNotifications();
      final code = await links.createCode(elder);
      await links.requestLink(caregiver, code.code);
      await links.approve((await links.linksOfElder(elder.uid).first).single);
      // Alerta cujo prazo já passou, sem confirmação do celular do idoso.
      await db.collection('elders').doc(elder.uid).collection('alerts').add({
        'type': 'fall',
        'status': 'awaiting',
        'createdAt': Timestamp.now(),
        'deadline': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(seconds: 30)),
        ),
      });
      final care = CaregiverController(
        profile: caregiver,
        links: links,
        notifications: notifications,
        db: db,
      )..start();
      addTearDown(care.dispose);
      await settle();
      expect(
        care.elders.single.situationAt(DateTime.now()),
        ElderSituation.emergency,
      );
      expect(notifications.caregiverAlerts.single, contains('não respondeu'));
    });
  });
}
