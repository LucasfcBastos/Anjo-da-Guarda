import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/medication.dart';

/// Salva os medicamentos no aparelho (dados em SharedPreferences
/// e fotos na pasta de documentos do app).
class MedicationRepository {
  static const _key = 'medications';
  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<List<Medication>> loadAll() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<Medication> meds) =>
      _prefs.setString(_key, jsonEncode(meds.map((m) => m.toJson()).toList()));

  /// A câmera grava a foto numa pasta temporária; copiamos para uma
  /// pasta permanente para que ela não seja apagada pelo sistema.
  Future<String> storePhoto(String tempPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/medicamentos');
    await dir.create(recursive: true);
    final target = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(tempPath).copy(target);
    return target;
  }

  Future<void> deletePhoto(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
