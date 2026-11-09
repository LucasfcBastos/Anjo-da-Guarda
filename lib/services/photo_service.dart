import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class PhotoException implements Exception {
  const PhotoException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Abre a câmera do celular para fotografar a caixa do remédio.
class PhotoService {
  final ImagePicker _picker = ImagePicker();

  /// Retorna o caminho da foto, ou `null` se o usuário cancelar.
  Future<String?> takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1280,
        imageQuality: 75,
        // Não lê metadados da galeria (evita pedir acesso às fotos no iOS).
        requestFullMetadata: false,
      );
      return photo?.path;
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw const PhotoException(
          'Permissão da câmera negada. Libere nas configurações do app.',
        );
      }
      if (e.code == 'no_available_camera') {
        throw const PhotoException('Este aparelho não tem câmera disponível.');
      }
      throw PhotoException('Não foi possível abrir a câmera: ${e.message}');
    }
  }

  /// No Android o sistema pode encerrar o app enquanto a câmera está aberta
  /// (pouca memória). Esta chamada recupera a foto tirada nesse caso.
  Future<String?> recoverLostPhoto() async {
    // Só existe no Android (app instalado).
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.isEmpty) return null;
    return response.file?.path;
  }
}
