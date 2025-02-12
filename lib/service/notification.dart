import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// The purpose of this class is to show a notification to the user
/// when the alarm rings so the user can understand where the audio
/// comes from. He also can tap the notification to open directly the app.
class AlarmNotification {
  static final instance = AlarmNotification._();

  final localNotif = FlutterLocalNotificationsPlugin();

  AlarmNotification._();

  static Function(NotificationResponse response)? _onNotTapIosAddition;
  static Function(NotificationResponse response)? _onNotTapAddition;

  /// Adds configuration for local notifications and initialize service.
  Future<void> init({
    required Function(NotificationResponse response) onNotTap,
    Function(NotificationResponse response)? onNotTapIos,
  }) async {
    _onNotTapAddition = onNotTap;
    _onNotTapIosAddition = onNotTapIos;
    const initializationSettingsAndroid = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
      onDidReceiveLocalNotification: onSelectNotificationOldIOS,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await localNotif.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: onSelectNotification,
      onDidReceiveNotificationResponse: onSelectNotification,
    );
    tz.initializeTimeZones();
  }

  // Callback to stop the alarm when the notification is opened.
  static onSelectNotification(NotificationResponse notificationResponse) async {
    _onNotTapAddition?.call(notificationResponse);
    if (notificationResponse.id == null) return;
    await stopAlarm(notificationResponse.id!);
  }

  // Callback to stop the alarm when the notification is opened for iOS versions older than 10.
  static onSelectNotificationOldIOS(
    int? id,
    String? title,
    String? body,
    String? payload,
  ) async {
    NotificationResponse response = NotificationResponse(
      id: id,
      notificationResponseType: NotificationResponseType.selectedNotification,
      actionId: title,
      input: body,
      payload: payload,
    );
    _onNotTapIosAddition?.call(response);
    if (id != null) await stopAlarm(id);
  }

  /// Stops the alarm.
  static Future<void> stopAlarm(int id) async {
    if (Alarm.getAlarm(id)?.stopOnNotificationOpen != null &&
        Alarm.getAlarm(id)!.stopOnNotificationOpen) {
      await Alarm.stop(id);
    }
  }

  /// Shows notification permission request.
  Future<bool> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await localNotif
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return await localNotif
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestExactAlarmsPermission() ??
          false;
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      // Return true for test purposes.
      return true;
    }

    return false;
  }

  tz.TZDateTime nextInstanceOfTime(DateTime dateTime) {
    final now = DateTime.now();

    if (dateTime.isBefore(now)) {
      dateTime = dateTime.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(dateTime, tz.local);
  }

  /// Schedules notification at the given [dateTime].
  Future<void> scheduleAlarmNotif({
    required int id,
    required DateTime dateTime,
    required String title,
    required String body,
    required bool fullScreenIntent,
    String? sound,
    String? channelId,
    String? channelName,
    String? channelDescription,
    String? payload,
  }) async {
    var iOSPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      sound: sound,
      subtitle: channelDescription,
      threadIdentifier: 'Harmonie',
    );

    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      channelId ?? 'alarm',
      channelName ?? 'alarm_plugin',
      channelDescription: channelDescription ?? 'Alarm plugin',
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound != null ? true : false,
      enableLights: true,
      sound: sound != null ? RawResourceAndroidNotificationSound(sound) : null,
      fullScreenIntent: fullScreenIntent,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final zdt = nextInstanceOfTime(dateTime);

    final hasPermission = await requestPermission();
    if (!hasPermission) {
      alarmPrint('Notification permission not granted');
      return;
    }

    try {
      await localNotif.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(zdt.toUtc(), tz.UTC),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      alarmPrint(
        'Notification with id $id scheduled successfuly at $zdt GMT',
      );
    } catch (e) {
      throw AlarmException('Schedule notification with id $id error: $e');
    }
  }

  /// Cancels notification. Called when the alarm is cancelled or
  /// when an alarm is overriden.
  Future<void> cancel(int id) async {
    await localNotif.cancel(id);
    alarmPrint('Notification with id $id canceled');
  }
}
