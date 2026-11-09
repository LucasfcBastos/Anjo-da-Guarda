/// Um medicamento cadastrado a partir de uma foto da caixa.
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.hour,
    required this.minute,
    required this.photoPath,
  });

  /// Também é usado como ID da notificação agendada.
  final int id;
  final String name;
  final int hour;
  final int minute;
  final String photoPath;

  /// Horário no formato 08:05.
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'hour': hour,
    'minute': minute,
    'photoPath': photoPath,
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as int,
    name: json['name'] as String,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    photoPath: json['photoPath'] as String,
  );
}
