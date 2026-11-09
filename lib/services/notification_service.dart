import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/emergency_alert.dart';
import '../models/medication.dart';

/// Centraliza as notificações locais do app (Android e iOS):
/// pergunta "Você está bem?", alerta de emergência e lembretes de remédio.
class NotificationService {
  static const int fallCheckId = 1;
  static const int emergencyId = 2;

  /// ID do botão "Estou bem" (Android e iOS usam o mesmo).
  static const String actionImOk = 'estou_bem';

  /// Categoria do iOS que contém o botão "Estou bem".
  static const String _iosFallCategory = 'queda';

  // Canais do Android (o usuário pode ajustar cada um nas configurações).
  static const _fallChannel = AndroidNotificationChannel(
    'queda',
    'Detecção de queda',
    description: 'Pergunta se você está bem após uma queda',
    importance: Importance.max,
  );
  static const _emergencyChannel = AndroidNotificationChannel(
    'emergencia',
    'Alertas de emergência',
    description: 'Alerta quando não há resposta após uma queda',
    importance: Importance.max,
  );
  static const _medicationChannel = AndroidNotificationChannel(
    'medicamentos',
    'Lembretes de medicamentos',
    description: 'Avisa no horário de cada remédio',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Chamado quando o usuário toca na notificação ou em um botão dela.
  void Function(String? actionId)? onAction;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  Future<void> init() async {
    // Fuso horário local, necessário para agendar lembretes no horário certo.
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      debugPrint(
        'Fuso horário não identificado ($e). Usando America/Sao_Paulo.',
      );
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }

    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          // A permissão é pedida depois, em requestPermission(),
          // junto com a de localização (igual ao Android).
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          // No iOS, botões de notificação são declarados em categorias.
          notificationCategories: [
            DarwinNotificationCategory(
              _iosFallCategory,
              actions: [
                DarwinNotificationAction.plain(
                  actionImOk,
                  'ESTOU BEM',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          onAction?.call(response.actionId),
    );

    // Android: cria os canais logo na inicialização.
    for (final channel in [
      _fallChannel,
      _emergencyChannel,
      _medicationChannel,
    ]) {
      await _android?.createNotificationChannel(channel);
    }
  }

  /// Pede a permissão de notificações (Android 13+ e iOS).
  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      return await _ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }

  /// Alarmes exatos deixam o lembrete tocar no minuto certo (Android 12+).
  /// No iOS não existe essa restrição: os lembretes já são pontuais.
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    return await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmsPermission() async =>
      _android?.requestExactAlarmsPermission();

  Future<AndroidScheduleMode> _scheduleMode() async =>
      await canScheduleExactAlarms()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // ---------------------------------------------------------------------------
  // Queda e emergência
  // ---------------------------------------------------------------------------

  Future<void> showFallCheck(int seconds) => _plugin.show(
    id: fallCheckId,
    title: 'Você está bem?',
    body:
        'Detectamos uma possível queda. Sem resposta em $seconds '
        'segundos, o alerta de emergência será acionado.',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _fallChannel.id,
        _fallChannel.name,
        channelDescription: _fallChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        ongoing: true,
        autoCancel: false,
        timeoutAfter: seconds * 1000,
        actions: const [
          AndroidNotificationAction(
            actionImOk,
            'ESTOU BEM',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: _iosFallCategory,
        interruptionLevel: InterruptionLevel.active,
      ),
    ),
  );

  Future<void> showEmergency(EmergencyAlert alert) {
    final body = _emergencyBody(alert);
    return _plugin.show(
      id: emergencyId,
      title: 'ALERTA DE EMERGÊNCIA',
      body: body,
      notificationDetails: _emergencyDetails(body),
    );
  }

  /// Reserva para quando o sistema pausa o app em segundo plano
  /// (comum no iOS): o alerta aparece no fim da contagem mesmo assim.
  Future<void> scheduleEmergencyBackup(DateTime when) async {
    const body =
        'Possível queda sem resposta. Abra o Anjo da Guarda para ver '
        'a localização.';
    await _plugin.zonedSchedule(
      id: emergencyId,
      title: 'ALERTA DE EMERGÊNCIA',
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      androidScheduleMode: await _scheduleMode(),
      notificationDetails: _emergencyDetails(body),
    );
  }

  String _emergencyBody(EmergencyAlert alert) {
    final position = alert.position;
    if (position == null) return alert.reason.description;
    return '${alert.reason.description}\n'
        'Local: ${position.latitude.toStringAsFixed(5)}, '
        '${position.longitude.toStringAsFixed(5)}';
  }

  NotificationDetails _emergencyDetails(String body) => NotificationDetails(
    android: AndroidNotificationDetails(
      _emergencyChannel.id,
      _emergencyChannel.name,
      channelDescription: _emergencyChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(
      interruptionLevel: InterruptionLevel.active,
    ),
  );

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  // ---------------------------------------------------------------------------
  // Lembretes de medicamentos
  // ---------------------------------------------------------------------------

  /// Agenda um lembrete que se repete todo dia no horário do remédio.
  Future<void> scheduleMedication(Medication med) async {
    await _plugin.zonedSchedule(
      id: med.id,
      title: 'Hora do remédio: ${med.name}',
      body: 'Está na hora de tomar ${med.name} (${med.timeLabel}).',
      scheduledDate: _nextInstanceOf(med.hour, med.minute),
      matchDateTimeComponents: DateTimeComponents.time, // repete diariamente
      androidScheduleMode: await _scheduleMode(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _medicationChannel.id,
          _medicationChannel.name,
          channelDescription: _medicationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          largeIcon: FilePathAndroidBitmap(med.photoPath),
          // Mostra a foto da caixa do remédio na notificação.
          styleInformation: BigPictureStyleInformation(
            FilePathAndroidBitmap(med.photoPath),
            contentTitle: 'Hora do remédio: ${med.name}',
            summaryText: med.timeLabel,
          ),
        ),
        iOS: DarwinNotificationDetails(
          interruptionLevel: InterruptionLevel.active,
          attachments: await _iosPhotoAttachment(med.photoPath),
        ),
      ),
    );
  }

  /// No iOS o sistema MOVE o arquivo anexado para a sua própria pasta.
  /// Por isso anexamos uma cópia da foto, preservando a original do app.
  Future<List<DarwinNotificationAttachment>?> _iosPhotoAttachment(
    String photoPath,
  ) async {
    if (!Platform.isIOS) return null;
    try {
      final temp = await getTemporaryDirectory();
      final copy = await File(photoPath).copy(
        '${temp.path}/lembrete_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      return [DarwinNotificationAttachment(copy.path)];
    } catch (e) {
      debugPrint('Sem foto no lembrete do iOS: $e');
      return null;
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var date = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!date.isAfter(now)) date = date.add(const Duration(days: 1));
    return date;
  }
}
