import 'package:cloud_firestore/cloud_firestore.dart';

enum LinkStatus { pending, active }

/// Vínculo entre um idoso e um cuidador, salvo em
/// `links/{elderId}_{caregiverId}`. O cuidador só tem acesso aos dados
/// do idoso quando o status é [LinkStatus.active] (aprovado pelo idoso).
class CareLink {
  const CareLink({
    required this.id,
    required this.elderId,
    required this.caregiverId,
    required this.elderName,
    required this.caregiverName,
    required this.status,
    this.createdAt,
    this.approvedAt,
  });

  final String id;
  final String elderId;
  final String caregiverId;
  final String elderName;
  final String caregiverName;
  final LinkStatus status;
  final DateTime? createdAt;
  final DateTime? approvedAt;

  bool get isActive => status == LinkStatus.active;

  static String idFor(String elderId, String caregiverId) =>
      '${elderId}_$caregiverId';

  factory CareLink.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CareLink(
      id: doc.id,
      elderId: d['elderId'] as String? ?? '',
      caregiverId: d['caregiverId'] as String? ?? '',
      elderName: d['elderName'] as String? ?? '',
      caregiverName: d['caregiverName'] as String? ?? '',
      status: d['status'] == 'active' ? LinkStatus.active : LinkStatus.pending,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      approvedAt: (d['approvedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Código temporário gerado pelo idoso, salvo em `linkCodes/{code}`.
class LinkCode {
  const LinkCode({
    required this.code,
    required this.elderId,
    required this.elderName,
    required this.expiresAt,
  });

  final String code;
  final String elderId;
  final String elderName;
  final DateTime expiresAt;

  bool isValidAt(DateTime now) => now.isBefore(expiresAt);

  factory LinkCode.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LinkCode(
      code: doc.id,
      elderId: d['elderId'] as String? ?? '',
      elderName: d['elderName'] as String? ?? '',
      expiresAt:
          (d['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
