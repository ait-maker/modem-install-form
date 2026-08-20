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

  // Firebase 초기화 - 실패해도 앱은 계속 실행 (로컬 데이터 사용)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('✅ Firebase initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ Firebase init failed (offline mode): $e');
    // Firebase 실패해도 로컬 SharedPreferences로 동작
  }

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
