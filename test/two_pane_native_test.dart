// Keep viewport fixtures compatible with Flutter 2.10.
// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen/split_screen.dart';

import 'native_channel_fixture.dart';

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => setState(() => count++),
        child: Center(child: Text('Count: $count')),
      );
}

Map<String, Object> _snapshot(Size size, [Rect? division]) => {
      'width': size.width,
      'height': size.height,
      'features': [
        if (division != null)
          {
            'left': division.left,
            'top': division.top,
            'right': division.right,
            'bottom': division.bottom,
            // An active division must work before any hinge-angle sample.
            'state': 'unknown',
          },
      ],
    };

void main() {
  late NativeChannelFixture native;
  setUp(() => native = NativeChannelFixture('split_screen/display_features'));
  tearDown(() => native.dispose());

  testWidgets(
    'unwrapped TwoPane preserves a Navigator through late folds and rotation',
    (tester) async {
      tester.binding.window.devicePixelRatioTestValue = 1;
      tester.binding.window.physicalSizeTestValue = const Size(500, 800);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      // Existing application code: no SplitScreen or platform-specific builder.
      await tester.pumpWidget(
        MaterialApp(
          home: TwoPane(
            panePriority: TwoPanePriority.start,
            startPane: Navigator(
              onGenerateRoute: (_) =>
                  MaterialPageRoute<void>(builder: (_) => const _Counter()),
            ),
            endPane: const ColoredBox(key: Key('end'), color: Colors.blue),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => const _Counter()),
      );
      await tester.pumpAndSettle();
      final counter = tester.state<_CounterState>(find.byType(_Counter).last);
      await tester.tap(find.text('Count: 0').last);
      await tester.pump();

      void expectState() {
        expect(tester.state(find.byType(Navigator).last), same(navigator));
        expect(tester.state(find.byType(_Counter).last), same(counter));
        expect(find.text('Count: 1'), findsOneWidget);
        expect(navigator.canPop(), isTrue);
      }

      await native.send(_snapshot(const Size(500, 800)));
      await tester.pump();
      expect(find.byKey(const Key('end')), findsNothing);
      expectState();

      await native.send(
        _snapshot(const Size(500, 800), const Rect.fromLTRB(230, 0, 270, 800)),
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('end'))),
        const Rect.fromLTRB(270, 0, 500, 800),
      );
      expectState();

      tester.binding.window.physicalSizeTestValue = const Size(800, 500);
      await tester.pump();
      expect(find.byKey(const Key('end')), findsNothing);
      expectState();
      // A zero-area seam still separates panes after matching metrics arrive.
      await native.send(
        _snapshot(const Size(800, 500), const Rect.fromLTRB(0, 250, 800, 250)),
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('end'))),
        const Rect.fromLTRB(0, 250, 800, 500),
      );
      expectState();

      await native.send(_snapshot(const Size(800, 500)));
      await tester.pump();
      expect(find.byKey(const Key('end')), findsNothing);
      expectState();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Count: 0'), findsOneWidget);
      expect(native.calls, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'concurrent panes share observation, replay and do not reapply full-view folds',
    (tester) async {
      tester.binding.window.devicePixelRatioTestValue = 1;
      tester.binding.window.physicalSizeTestValue = const Size(800, 600);
      addTearDown(tester.binding.window.clearDevicePixelRatioTestValue);
      addTearDown(tester.binding.window.clearPhysicalSizeTestValue);
      Widget app({bool second = false}) => MaterialApp(
            home: Stack(
              fit: StackFit.expand,
              children: [
                const TwoPane(
                  startPane: TwoPane(
                    padding: EdgeInsets.only(right: 410),
                    startPane: ColoredBox(
                      key: Key('nestedStart'),
                      color: Colors.red,
                    ),
                    endPane:
                        ColoredBox(key: Key('nestedEnd'), color: Colors.blue),
                  ),
                  endPane:
                      ColoredBox(key: Key('outerEnd'), color: Colors.green),
                ),
                if (second)
                  const TwoPane(
                    startPane: SizedBox(),
                    endPane:
                        ColoredBox(key: Key('replay'), color: Colors.yellow),
                  ),
              ],
            ),
          );
      await tester.pumpWidget(app());
      await tester.pump();
      await native.send(
        _snapshot(const Size(800, 600), const Rect.fromLTRB(390, 0, 410, 600)),
      );
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('outerEnd'))),
        const Rect.fromLTRB(410, 0, 800, 600),
      );
      // The existing padding contract locates this nested layout in its pane.
      expect(
        tester.getRect(find.byKey(const Key('nestedStart'))),
        const Rect.fromLTRB(0, 0, 195, 600),
      );
      expect(
        tester.getRect(find.byKey(const Key('nestedEnd'))),
        const Rect.fromLTRB(195, 0, 390, 600),
      );
      await tester.pumpWidget(app(second: true));
      await tester.pump();
      expect(
        tester.getRect(find.byKey(const Key('replay'))),
        const Rect.fromLTRB(410, 0, 800, 600),
      );
      expect(native.calls, ['listen']);
      await tester.pumpWidget(app());
      await tester.pump();
      expect(native.calls, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'unwrapped TwoPane honors engine geometry and explicit overrides on $platform',
      (tester) async {
        Widget app(Set<TwoPaneAllowedOverrides> overrides) => MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(800, 600),
                  displayFeatures: [
                    DisplayFeature(
                      bounds: Rect.fromLTRB(300, 0, 320, 600),
                      type: DisplayFeatureType.hinge,
                      state: DisplayFeatureState.unknown,
                    ),
                  ],
                ),
                child: TwoPane(
                  allowedOverrides: overrides,
                  paneProportion: 0.25,
                  startPane: const SizedBox(),
                  endPane:
                      const ColoredBox(key: Key('end'), color: Colors.blue),
                ),
              ),
            );
        await tester.pumpWidget(app(TwoPaneAllowedOverrides.values.toSet()));
        await tester.pump();
        if (platform == TargetPlatform.iOS) {
          await native.send(
            _snapshot(
              const Size(800, 600),
              const Rect.fromLTRB(390, 0, 410, 600),
            ),
          );
          await tester.pump();
        }
        expect(
          tester.getRect(find.byKey(const Key('end'))),
          const Rect.fromLTRB(320, 0, 800, 600),
        );
        await tester.pumpWidget(app({TwoPaneAllowedOverrides.direction}));
        expect(
          tester.getRect(find.byKey(const Key('end'))),
          const Rect.fromLTRB(200, 0, 800, 600),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(
          native.calls,
          platform == TargetPlatform.iOS ? ['listen', 'cancel'] : isEmpty,
        );
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'optional root wrapper and automatic TwoPane share one native lifetime',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => SplitScreen(child: child),
          home: const TwoPane(startPane: SizedBox(), endPane: SizedBox()),
        ),
      );
      await tester.pump();
      await native.send(_snapshot(const Size(800, 600)));
      await tester.pump();
      expect(native.calls, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'automatic observation respects display features removed by an ancestor',
    (tester) async {
      late List<DisplayFeature> features;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => SplitScreen(child: child),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(displayFeatures: const []),
              child: TwoPane(
                padding: const EdgeInsets.only(right: 410),
                startPane: Builder(
                  builder: (context) {
                    features = MediaQuery.of(context).displayFeatures;
                    return const SizedBox();
                  },
                ),
                endPane: const SizedBox(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await native.send(
        _snapshot(const Size(800, 600), const Rect.fromLTRB(390, 0, 410, 600)),
      );
      await tester.pump();
      expect(features, isEmpty);
      expect(native.calls, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'unwrapped TwoPane falls back when native layout support is absent',
    (tester) async {
      native.messenger.setMockMessageHandler(native.name, (_) async => null);
      await tester.pumpWidget(
        const MaterialApp(
          home: TwoPane(
            panePriority: TwoPanePriority.start,
            startPane: Text('Fallback'),
            endPane: Text('Second'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Fallback'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
