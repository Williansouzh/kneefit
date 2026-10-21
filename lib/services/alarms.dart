import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';

/// Alarmes de refeição: uma notificação diária no horário de cada refeição, agendada no aparelho.
/// Usa alarme exato quando o Android deixa; senão, aproximado (pode atrasar alguns minutos).
class Alarms {
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'refeicoes',
    'Refeições',
    channelDescription: 'Lembrete na hora de cada refeição',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _init() async {
    if (_ready || !supported) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    }
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Pede a permissão de notificação (Android 13+). Falso se negada.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Reagenda todas as refeições com alarme ligado.
  Future<void> sync(List<Meal> meals) async {
    if (!supported) return;
    await _init();
    await _plugin.cancelAll();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = await android?.canScheduleExactNotifications() ?? false;
    final now = tz.TZDateTime.now(tz.local);
    for (final (i, m) in meals.indexed) {
      if (!m.alarm) continue;
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, m.hour, m.minute);
      if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: 100 + i,
        title: 'Hora do ${m.name.toLowerCase()} 🍽️',
        body: m.hint.isEmpty ? 'Bora comer: é isso que faz o treino virar músculo.' : m.hint,
        scheduledDate: at,
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }
}
