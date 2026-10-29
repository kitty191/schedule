import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_controller.dart';

import 'today_page.dart';
import 'week_page.dart';
import 'profile_page.dart';
import 'glass_dock.dart';
import 'components.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final compact = compactLandscape(context);
    final bottom = MediaQuery.paddingOf(context).bottom + 10;
    return CupertinoPageScaffold(
      // Main tabs contain no text input. Sheets/routes above this page handle
      // the keyboard themselves; keep the background from shrinking behind it.
      resizeToAvoidBottomInset: false,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Stack(
          children: [
            Positioned.fill(
              bottom: compact ? bottom + GlassDock.compactHeight + 8 : 0,
              child: ref
                  .watch(appProvider)
                  .when(
                    loading: () =>
                        const Center(child: CupertinoActivityIndicator()),
                    error: (_, _) => Center(
                      child: CupertinoButton(
                        key: const Key('retry-load'),
                        onPressed: () => ref.invalidate(appProvider),
                        child: const Text('读取失败，点击重试'),
                      ),
                    ),
                    data: (_) => IndexedStack(
                      index: _index,
                      children: const [TodayPage(), WeekPage(), ProfilePage()],
                    ),
                  ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: bottom,
              child: Center(
                child: GlassDock(
                  compact: compact,
                  selectedIndex: _index,
                  onSelected: (index) => setState(() => _index = index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
