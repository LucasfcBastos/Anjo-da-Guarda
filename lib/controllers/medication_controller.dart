import 'package:flutter/foundation.dart';

import '../models/medication.dart';
import '../services/medication_repository.dart';
import '../services/notification_service.dart';

/// Lista de medicamentos: salva no aparelho e agenda os lembretes.
class MedicationController extends ChangeNotifier {
  MedicationController({
    required this._repository,
    required this._notifications,
  });

  final MedicationRepository _repository;
  final NotificationService _notifications;

  List<Medication> _items = [];
  bool _loading = true;

  List<Medication> get items => List.unmodifiable(_items);
  bool get isLoading => _loading;

  Future<void> load() async {
    try {
      _items = await _repository.loadAll();
      _sort();
    } catch (e) {
      debugPrint('Erro ao carregar medicamentos: $e');
    }
    _loading = false;
    notifyListeners();
  }

  /// Foto tirada → nome e horário → salva e programa a notificação diária.
  Future<void> add({
    required String name,
    required int hour,
    required int minute,
    required String tempPhotoPath,
  }) async {
    final photoPath = await _repository.storePhoto(tempPhotoPath);
    final med = Medication(
      // ID positivo de 32 bits, também usado na notificação.
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30) + 100,
      name: name,
      hour: hour,
      minute: minute,
      photoPath: photoPath,
    );
    _items = [..._items, med];
    _sort();
    await _repository.saveAll(_items);
    await _notifications.scheduleMedication(med);
    notifyListeners();
  }

  Future<void> remove(Medication med) async {
    _items = _items.where((m) => m.id != med.id).toList();
    await _repository.saveAll(_items);
    await _notifications.cancel(med.id);
    await _repository.deletePhoto(med.photoPath);
    notifyListeners();
  }

  /// Próximo remédio a ser tomado a partir de agora.
  Medication? nextMedication([DateTime? now]) {
    if (_items.isEmpty) return null;
    final t = now ?? DateTime.now();
    final minutesNow = t.hour * 60 + t.minute;
    for (final m in _items) {
      if (m.hour * 60 + m.minute > minutesNow) return m;
    }
    return _items.first; // amanhã
  }

  void _sort() => _items.sort(
    (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
  );
}
