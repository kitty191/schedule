import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'today_page.dart';
import 'week_page.dart';
import 'profile_page.dart';

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
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 10,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    width: 246,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: CupertinoColors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: CupertinoColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: Semantics(
                              selected: _index == i,
                              button: true,
                              child: CupertinoButton(
                                key: Key('tab-$i'),
                                padding: EdgeInsets.zero,
                                onPressed: () => setState(() => _index = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 50,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _index == i
                                        ? const Color(0xFFE4F0FF)
                                        : CupertinoColors.white.withValues(
                                            alpha: 0,
                                          ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        const [
                                          CupertinoIcons.calendar,
                                          CupertinoIcons.square_grid_2x2,
                                          CupertinoIcons.person,
                                        ][i],
                                        size: 20,
                                        color: _index == i
                                            ? CupertinoColors.activeBlue
                                            : CupertinoColors.systemGrey,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        const ['日程', '课表', '我的'][i],
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _index == i
                                              ? CupertinoColors.activeBlue
                                              : CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
