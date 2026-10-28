import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen/split_screen.dart';

void main() {
  for (final horizontal in [true, false]) {
    for (final rtl in [true, false]) {
      testWidgets(
        'zero-area fold horizontal=$horizontal rtl=$rtl separates panes',
        (tester) async {
          const start = Key('start');
          const end = Key('end');
          final bounds = horizontal
              ? const Rect.fromLTRB(400, 0, 400, 600)
              : const Rect.fromLTRB(0, 300, 800, 300);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: const Size(800, 600),
                displayFeatures: [
                  DisplayFeature(
                    bounds: bounds,
                    type: DisplayFeatureType.fold,
                    state: DisplayFeatureState.postureHalfOpened,
                  ),
                ],
              ),
              child: TwoPane(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                startPane: const SizedBox(key: start),
                endPane: const SizedBox(key: end),
                panePriority: TwoPanePriority.start,
                paneProportion: 0.1,
                direction: horizontal ? Axis.vertical : Axis.horizontal,
              ),
            ),
          );
          expect(
            tester.getSize(find.byKey(start)),
            horizontal ? const Size(400, 600) : const Size(800, 300),
          );
          expect(
            tester.getSize(find.byKey(end)),
            horizontal ? const Size(400, 600) : const Size(800, 300),
          );
          expect(
            tester.getTopLeft(find.byKey(start)),
            horizontal && rtl ? const Offset(400, 0) : Offset.zero,
          );
        },
      );
    }
  }
  test('fold accessor returns first fold and hinge remains hinge-only', () {
    const first = DisplayFeature(
      bounds: Rect.fromLTRB(400, 0, 400, 600),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureHalfOpened,
    );
    const second = DisplayFeature(
      bounds: Rect.fromLTRB(0, 300, 800, 300),
      type: DisplayFeatureType.fold,
      state: DisplayFeatureState.postureFlat,
    );
    const data = MediaQueryData(displayFeatures: [first, second]);
    expect(data.fold, same(first));
    expect(data.hinge, isNull);
    expect(const MediaQueryData().fold, isNull);
  });
}
