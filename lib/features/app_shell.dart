import 'package:flutter/cupertino.dart';

import 'today_page.dart';
import 'week_page.dart';
import 'profile_page.dart';
import 'glass_dock.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    child: Stack(
      children: [
        IndexedStack(
          index: _index,
          children: const [TodayPage(), WeekPage(), ProfilePage()],
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(context).bottom + 10,
          child: Center(
            child: GlassDock(
              selectedIndex: _index,
              onSelected: (index) => setState(() => _index = index),
            ),
          ),
        ),
      ],
    ),
  );
}
