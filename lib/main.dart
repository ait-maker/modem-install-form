import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/data_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 - 8초 타임아웃 적용
  // 네트워크 불안정 또는 Firebase 서버 지연 시 runApp 자체가 블로킹되는 것을 방지
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        if (kDebugMode) debugPrint('⚠️ Firebase init timeout — 오프라인 모드로 전환');
        // timeout 시 예외를 throw하여 아래 catch에서 처리
        throw TimeoutException('Firebase init timeout');
      },
    );
    if (kDebugMode) debugPrint('✅ Firebase initialized');
  } catch (e) {
    // Firebase 실패 / 타임아웃 → 로컬 SharedPreferences로 동작
    if (kDebugMode) debugPrint('⚠️ Firebase 초기화 실패 (로컬 모드): $e');
  }

  // Firebase 결과와 무관하게 항상 앱 실행
  runApp(const ModemManagerApp());
}

class ModemManagerApp extends StatelessWidget {
  const ModemManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService()..loadRequests(),
      child: MaterialApp(
        title: '무선모뎀 설치접수',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko', 'KR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('ko', 'KR'),
        // ── 전역 textScaler 제거: AppResponsive가 폰트 크기를 직접 제어하므로
        // ── textScaler를 추가 적용하면 fontMd 18px * 1.45 = 26px로 폭발하여
        // ── TextField/Dropdown 높이 overflow → 접수폼 렌더링 실패의 원인이었음
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
