import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/care_link.dart';
import '../models/user_profile.dart';

class LinkException implements Exception {
  const LinkException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Vinculação entre idoso e cuidador:
/// 1. o idoso gera um código temporário;
/// 2. o cuidador digita o código e cria um pedido (status "pending");
/// 3. o idoso aprova (status "active").
/// As regras do Firestore (firebase/firestore.rules) validam cada passo.
class LinkService {
  LinkService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Sem letras e números parecidos (I/1, O/0) para facilitar a leitura.
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const codeLength = 6;
  static const codeValidity = Duration(minutes: 30);

  static String generateCode([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(
      codeLength,
      (_) => alphabet[r.nextInt(alphabet.length)],
    ).join();
  }

  /// Aceita minúsculas, espaços e hífens ("abc-234" → "ABC234").
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

  static bool isWellFormed(String code) =>
      code.length == codeLength && code.split('').every(alphabet.contains);

  CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('linkCodes');
  CollectionReference<Map<String, dynamic>> get _links =>
      _db.collection('links');

  // --- Idoso ------------------------------------------------------------------

  /// Códigos do idoso (o app mostra o mais recente ainda válido).
  Stream<List<LinkCode>> codesOf(String elderId) => _codes
      .where('elderId', isEqualTo: elderId)
      .snapshots()
      .map((s) => s.docs.map(LinkCode.fromDoc).toList());

  /// Gera um código novo e apaga os anteriores do mesmo idoso.
  /// Exige internet (transação), para o código já valer no servidor.
  Future<LinkCode> createCode(UserProfile elder) async {
    final old = await _codes.where('elderId', isEqualTo: elder.uid).get();
    for (final doc in old.docs) {
      await doc.reference.delete();
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateCode();
      final ref = _codes.doc(code);
      final expiresAt = DateTime.now().add(codeValidity);
      final created = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) return false; // código já usado: tenta outro
        tx.set(ref, {
          'elderId': elder.uid,
          'elderName': elder.name,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresAt),
        });
        return true;
      });
      if (created) {
        return LinkCode(
          code: code,
          elderId: elder.uid,
          elderName: elder.name,
          expiresAt: expiresAt,
        );
      }
    }
    throw const LinkException(
      'Não foi possível gerar o código. Tente de novo.',
    );
  }

  Stream<List<CareLink>> linksOfElder(String elderId) => _links
      .where('elderId', isEqualTo: elderId)
      .snapshots()
      .map((s) => s.docs.map(CareLink.fromDoc).toList());

  Future<void> approve(CareLink link) => _links.doc(link.id).update({
    'status': 'active',
    'approvedAt': FieldValue.serverTimestamp(),
  });

  /// Recusar pedido, remover cuidador (idoso) ou deixar de acompanhar (cuidador).
  Future<void> remove(CareLink link) => _links.doc(link.id).delete();

  // --- Cuidador ---------------------------------------------------------------

  Stream<List<CareLink>> linksOfCaregiver(String caregiverId) => _links
      .where('caregiverId', isEqualTo: caregiverId)
      .snapshots()
      .map((s) => s.docs.map(CareLink.fromDoc).toList());

  /// O cuidador informa o código; cria um pedido que o idoso precisa aprovar.
  /// Retorna o nome do idoso.
  Future<String> requestLink(UserProfile caregiver, String rawCode) async {
    final code = normalize(rawCode);
    if (!isWellFormed(code)) {
      throw const LinkException(
        'O código tem 6 letras e números. Confira e digite de novo.',
      );
    }
    return _db.runTransaction<String>((tx) async {
      final codeSnap = await tx.get(_codes.doc(code));
      if (!codeSnap.exists) {
        throw const LinkException(
          'Código não encontrado. Confira com o idoso ou peça um novo.',
        );
      }
      final linkCode = LinkCode.fromDoc(codeSnap);
      if (!linkCode.isValidAt(DateTime.now())) {
        throw const LinkException(
          'Este código expirou. Peça ao idoso para gerar um novo.',
        );
      }
      final ref = _links.doc(CareLink.idFor(linkCode.elderId, caregiver.uid));
      final existing = await tx.get(ref);
      if (existing.exists) {
        throw LinkException(
          CareLink.fromDoc(existing).isActive
              ? 'Você já acompanha ${linkCode.elderName}.'
              : 'Pedido já enviado. Aguarde ${linkCode.elderName} aprovar.',
        );
      }
      tx.set(ref, {
        'elderId': linkCode.elderId,
        'caregiverId': caregiver.uid,
        'elderName': linkCode.elderName,
        'caregiverName': caregiver.name,
        'status': 'pending',
        'code': code,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return linkCode.elderName;
    });
  }
}
