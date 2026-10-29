import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:schedule/data/database.dart';
import 'package:schedule/data/timetable_settings.dart';
import 'package:schedule/features/week_page.dart';

void main() {
  for (final density in [60, 80]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
        'Late class stays readable at $density percent, text scale $scale',
        (tester) async {
          tester.view.physicalSize = const Size(393, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final settings = TimetableSettings.defaults().copyWith(
            heightPercent: density,
          );
          final last = settings.periods.last;
          final start = last.end + 25;
          final end = start + 90;
          final axis = TimetableAxis(settings, earliest: 420, latest: end);
          final perMinute =
              (axis.at(last.end) - axis.at(last.start)) /
              (last.end - last.start);
          expect(axis.at(end) - axis.at(start), closeTo(perMinute * 90, 0.01));
          final courses = [
            Course(
              id: 1,
              name: '概率论与数理统计',
              location: 'C3-104 教学楼',
              weekday: 2,
              startMinute: start,
              endMinute: end,
              colorIndex: 0,
            ),
          ];
          await tester.pumpWidget(
            CupertinoApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(393, 852),
                  textScaler: TextScaler.linear(scale),
                ),
                child: CupertinoPageScaffold(
                  child: SafeArea(
                    child: WeekGrid(
                      key: const Key('capture'),
                      weekStart: DateTime(2026, 10, 26),
                      courses: courses,
                      settings: settings,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final card = find.byKey(const Key('course-card-1-1'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          expect(tester.getSize(card).height, greaterThan(95));
          expect(find.text('概率论与数理统计'), findsOneWidget);
          expect(find.text('C3-104 教学楼'), findsOneWidget);
          final title = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.text('概率论与数理统计'),
              matching: find.byType(RichText),
            ),
          );
          expect(title.didExceedMaxLines, isFalse);
          for (final box in title.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 8),
          )) {
            expect(box.bottom, lessThanOrEqualTo(title.size.height + 0.01));
          }
          expect(find.byKey(const Key('extended-time-20')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
