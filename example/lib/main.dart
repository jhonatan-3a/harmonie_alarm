import 'dart:async';
import 'package:alarm_example/screens/home.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Alarm.init(
      showDebugLogs: true, onNotTap: (a) {}, onNotTapIos: (a, b, c, d) {});

  runApp(const MaterialApp(home: ExampleAlarmHomeScreen()));
}
