import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de conta escolhido no cadastro.
enum UserRole {
  elder('elder', 'Idoso'),
  caregiver('caregiver', 'Cuidador');

  const UserRole(this.id, this.label);

  /// Valor gravado no Firestore.
  final String id;
  final String label;

  static UserRole? fromId(Object? id) {
    for (final role in values) {
      if (role.id == id) return role;
    }
    return null;
  }
}

/// Perfil salvo em `users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  bool get isElder => role == UserRole.elder;

  /// Retorna `null` se o documento estiver incompleto.
  static UserProfile? fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final role = UserRole.fromId(data['role']);
    final name = data['name'];
    if (role == null || name is! String) return null;
    return UserProfile(
      uid: doc.id,
      name: name,
      email: data['email'] as String? ?? '',
      role: role,
    );
  }
}
