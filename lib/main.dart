import 'dart:async'; // ✅ [변경] 전역 예외 캐치용
import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/logger_service.dart'; // ✅ [변경] 로그 기록

void main() {
  // ✅ [변경] Flutter 프레임워크 에러 로깅
  FlutterError.onError = (FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    await LoggerService.I.e(
      'FlutterError',
      error: details.exception,
      st: details.stack,
    );
  };

  // ✅ [변경] 비동기/기타 예외도 로깅
  runZonedGuarded(() {
    runApp(const BridgeCameraApp());
  }, (error, st) async {
    await LoggerService.I.e('Uncaught(zone)', error: error, st: st);
  });
}

class BridgeCameraApp extends StatelessWidget {
  const BridgeCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '점검도우미',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
