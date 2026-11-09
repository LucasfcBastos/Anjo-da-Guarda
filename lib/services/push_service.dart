import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

enum PushState { checking, registered, denied, unavailable }

/// Registra este celular para receber notificações push (FCM) com o app
/// fechado. O token fica em `users/{uid}/devices/{token}`; quem envia o
/// push é a Cloud Function em firebase/functions (exige o plano Blaze).
///
/// Usa o token FCM clássico (getToken), que o firebase-admin envia com
/// sendEachForMulticast. A API nova por FID (register/onRegistered) ainda
/// não é usada porque exige outro formato de envio no servidor.
// ignore_for_file: deprecated_member_use
class PushService extends ChangeNotifier {
  PushService({
    required this.uid,
    FirebaseMessaging? messaging,
    FirebaseFirestore? db,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _db = db ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;

  StreamSubscription<String>? _refreshSub;
  String? _token;
  bool _disposed = false;

  PushState _state = PushState.checking;
  String? _detail;

  PushState get state => _state;
  String? get detail => _detail;

  DocumentReference<Map<String, dynamic>> _deviceRef(String token) =>
      _db.collection('users').doc(uid).collection('devices').doc(token);

  Future<void> register() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _update(
          PushState.denied,
          'Notificações bloqueadas. Libere nas configurações do celular.',
        );
        return;
      }
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.iOS &&
          await _messaging.getAPNSToken() == null) {
        // Sem a capacidade "Push Notifications" e a chave APNs no Firebase,
        // o iPhone não recebe push. Os alertas chegam com o app aberto.
        _update(
          PushState.unavailable,
          'Push no iPhone ainda não configurado (precisa da chave APNs).',
        );
        return;
      }
      final token = await _messaging.getToken();
      if (token == null) {
        _update(PushState.unavailable, 'Não foi possível registrar o push.');
        return;
      }
      await _saveToken(token);
      _refreshSub ??= _messaging.onTokenRefresh.listen((t) async {
        final old = _token;
        await _saveToken(t);
        if (old != null && old != t) {
          await _deviceRef(old).delete().catchError((_) {});
        }
      });
      _update(PushState.registered, null);
    } catch (e) {
      debugPrint('Push indisponível: $e');
      _update(PushState.unavailable, 'Push indisponível neste aparelho.');
    }
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    await _deviceRef(token).set({
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Ao sair da conta: este celular para de receber os alertas.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token = _token;
    if (token == null) return;
    try {
      await _deviceRef(token).delete().timeout(const Duration(seconds: 5));
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('Não foi possível remover o token: $e');
    }
    _token = null;
  }

  void _update(PushState state, String? detail) {
    if (_disposed) return;
    _state = state;
    _detail = detail;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshSub?.cancel();
    super.dispose();
  }
}
