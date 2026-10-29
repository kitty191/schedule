import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/today_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ScheduleApp()));
}

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context) => const CupertinoApp(
    debugShowCheckedModeBanner: false,
    title: '今天课程',
    locale: Locale('zh', 'CN'),
    localizationsDelegates: GlobalCupertinoLocalizations.delegates,
    supportedLocales: [Locale('zh', 'CN')],
    theme: CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: Color(0xFF007AFF),
      scaffoldBackgroundColor: Color(0xFFF5F6FA),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle(fontSize: 16, color: Color(0xFF1C1C1E)),
      ),
    ),
    home: TodayPage(),
  );
}
