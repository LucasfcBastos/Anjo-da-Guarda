import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

/// Login e cadastro por e-mail e senha (Firebase Authentication)
/// e perfil do usuário em `users/{uid}` (Cloud Firestore).
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Verdadeiro entre a criação da conta e a gravação do perfil,
  /// para a tela não mostrar "complete seu perfil" nesse intervalo.
  final ValueNotifier<bool> registering = ValueNotifier(false);

  Stream<User?> authChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _db.collection('users').doc(uid);

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileSnapshots(String uid) =>
      _profileRef(uid).snapshots(includeMetadataChanges: true);

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    registering.value = true;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await createProfile(user: user, name: name, role: role);
      await user.updateDisplayName(name.trim());
    } finally {
      registering.value = false;
    }
  }

  /// Também usado quando a conta existe mas o perfil não foi gravado
  /// (ex.: a internet caiu logo após criar a conta).
  Future<void> createProfile({
    required User user,
    required String name,
    required UserRole role,
  }) => _profileRef(user.uid).set({
    'name': name.trim(),
    'email': user.email,
    'role': role.id,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();
}

/// Mensagem em português para erros de login, cadastro e Firestore.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'E-mail inválido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'E-mail ou senha incorretos.',
      'email-already-in-use' => 'Já existe uma conta com este e-mail.',
      'weak-password' => 'Senha fraca. Use pelo menos 6 caracteres.',
      'network-request-failed' =>
        'Sem conexão com a internet. Verifique e tente de novo.',
      'too-many-requests' =>
        'Muitas tentativas. Aguarde alguns minutos e tente de novo.',
      'operation-not-allowed' =>
        'Login por e-mail e senha não está ativado no Firebase '
            '(Authentication → Sign-in method).',
      _ => 'Erro de autenticação (${error.code}).',
    };
  }
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Acesso negado pelas regras de segurança.',
      'unavailable' => 'Sem conexão com o servidor. Verifique a internet.',
      _ => 'Erro no servidor (${error.code}).',
    };
  }
  return 'Erro inesperado: $error';
}
