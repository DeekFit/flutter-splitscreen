import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show MaterialApp;
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen/split_screen.dart';
import 'package:split_screen/src/display_features.dart';
import 'native_channel_fixture.dart';

class _CounterProbe extends StatefulWidget {
  const _CounterProbe();

  @override
  State<_CounterProbe> createState() => _CounterProbeState();
}

class _CounterProbeState extends State<_CounterProbe> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: Text('Count: $count'),
  );
}

class _ProbeRouterDelegate extends RouterDelegate<Object> with ChangeNotifier {
  @override
  Widget build(BuildContext context) => const _CounterProbe();

  @override
  Future<void> setNewRoutePath(Object configuration) async {}

  @override
  Future<bool> popRoute() async => false;
}

Map<String, Object> snapshot({
  double width = 800,
  double height = 600,
  List<Object?>? features,
}) => {
  'width': width,
  'height': height,
  'features':
      features ??
      [
        <String, Object>{
          'left': 390,
          'top': 0,
          'right': 410,
          'bottom': 600,
          'state': 'halfOpened',
        },
      ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeChannelFixture native;
  setUp(() {
    native = NativeChannelFixture('split_screen/display_features');
  });
  tearDown(() => native.dispose());

  testWidgets(
    'child state survives initial geometry, resize and engine precedence',
    (tester) async {
      Widget app({Size size = const Size(800, 600), bool engineFold = false}) =>
          Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                displayFeatures: engineFold
                    ? const [
                        DisplayFeature(
                          bounds: Rect.fromLTRB(0, 390, 600, 410),
                          type: DisplayFeatureType.fold,
                          state: DisplayFeatureState.postureFlat,
                        ),
                      ]
                    : const [],
              ),
              child: const SplitScreen(child: _CounterProbe()),
            ),
          );
      await tester.pumpWidget(app());
      await tester.pump();
      final state = tester.state<_CounterProbeState>(
        find.byType(_CounterProbe),
      );
      await tester.tap(find.text('Count: 0'));
      await tester.pump();

      void expectPreserved() {
        expect(
          tester.state<_CounterProbeState>(find.byType(_CounterProbe)),
          same(state),
        );
        expect(find.text('Count: 1'), findsOneWidget);
      }

      await native.send(snapshot(features: []));
      await tester.pump();
      expectPreserved();
      await native.send(snapshot());
      await tester.pump();
      expectPreserved();
      await tester.pumpWidget(app(size: const Size(600, 800)));
      expectPreserved();
      await native.send(
        snapshot(
          width: 600,
          height: 800,
          features: [
            {
              'left': 0,
              'top': 390,
              'right': 600,
              'bottom': 410,
              'state': 'halfOpened',
            },
          ],
        ),
      );
      await tester.pump();
      expectPreserved();
      await tester.pumpWidget(
        app(size: const Size(600, 800), engineFold: true),
      );
      expectPreserved();
      await tester.pumpWidget(app(size: const Size(600, 800)));
      expectPreserved();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'MaterialApp.router retains Router and child state on initial snapshot',
    (tester) async {
      final delegate = _ProbeRouterDelegate();
      addTearDown(delegate.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: delegate,
          builder: (context, child) => SplitScreen(child: child),
        ),
      );
      await tester.pumpAndSettle();
      final router = tester.element(find.byType(Router<Object>));
      final state = tester.state<_CounterProbeState>(
        find.byType(_CounterProbe),
      );
      await tester.tap(find.text('Count: 0'));
      await tester.pump();
      final size = MediaQuery.of(
        tester.element(find.byType(_CounterProbe)),
      ).size;
      await native.send(
        snapshot(width: size.width, height: size.height, features: []),
      );
      await tester.pump();
      expect(tester.element(find.byType(Router<Object>)), same(router));
      expect(
        tester.state<_CounterProbeState>(find.byType(_CounterProbe)),
        same(state),
      );
      expect(find.text('Count: 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('malformed snapshots are ignored, seams and posture are preserved', () {
    for (final payload in [
      null,
      1,
      <Object?, Object?>{},
      {'width': 800, 'height': double.nan, 'features': <Object?>[]},
      snapshot(features: [null]),
      snapshot(
        features: [
          {'left': -1, 'top': 0, 'right': 5, 'bottom': 600},
        ],
      ),
      snapshot(
        features: [
          {'left': 5, 'top': 1, 'right': 4, 'bottom': 600},
        ],
      ),
      snapshot(
        features: [
          {'left': 4, 'top': 1, 'right': double.infinity, 'bottom': 600},
        ],
      ),
      snapshot(
        features: [
          {'left': 4, 'top': 1, 'right': 900, 'bottom': 600},
        ],
      ),
    ]) {
      expect(DisplayFeaturesSnapshot.decode(payload), isNull);
    }
    for (final state in ['halfOpened', 'flat', 'unknown']) {
      final result = DisplayFeaturesSnapshot.decode(
        snapshot(
          features: [
            {
              'left': 400,
              'right': 400,
              'top': 0,
              'bottom': 600,
              'state': state,
            },
            {
              'left': 0,
              'right': 800,
              'top': 300,
              'bottom': 300,
              'state': state,
            },
          ],
        ),
      )!;
      expect(result.features.first.bounds.width, 0);
      expect(result.features.last.bounds.height, 0);
      expect(result.features.first.state, switch (state) {
        'halfOpened' => DisplayFeatureState.postureHalfOpened,
        'flat' => DisplayFeatureState.postureFlat,
        _ => DisplayFeatureState.unknown,
      });
    }
  });

  testWidgets(
    'late initial geometry augments metrics, then removal clears it',
    (tester) async {
      late MediaQueryData observed;
      final data = MediaQueryData(
        size: const Size(800, 600),
        padding: const EdgeInsets.all(7),
        viewInsets: const EdgeInsets.only(bottom: 12),
        devicePixelRatio: 2,
        textScaler: const TextScaler.linear(1.2),
        platformBrightness: Brightness.dark,
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 0, 5, 5),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: SplitScreen(
            child: Builder(
              builder: (context) {
                observed = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(native.calls, ['listen']);
      await native.send(snapshot(features: []));
      await tester.pump();
      expect(observed, data);
      await native.send(snapshot());
      await tester.pump();
      expect(observed.fold!.bounds, const Rect.fromLTRB(390, 0, 410, 600));
      expect(observed.hinge, isNull);
      expect(observed.copyWith(displayFeatures: data.displayFeatures), data);
      await native.send(snapshot(features: []));
      await tester.pump();
      expect(observed, data);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'resize discards stale geometry until matching viewport arrives',
    (tester) async {
      late MediaQueryData observed;
      Widget app(Size size) => MediaQuery(
        data: MediaQueryData(size: size),
        child: SplitScreen(
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(app(const Size(800, 600)));
      await tester.pump();
      await native.send(snapshot());
      await tester.pump();
      expect(observed.fold, isNotNull);
      await tester.pumpWidget(app(const Size(600, 800)));
      expect(observed.fold, isNull);
      await native.send(snapshot());
      await tester.pump();
      expect(observed.fold, isNull);
      await native.send(
        snapshot(
          width: 600,
          height: 800,
          features: [
            {
              'left': 0,
              'top': 390,
              'right': 600,
              'bottom': 410,
              'state': 'flat',
            },
          ],
        ),
      );
      await tester.pump();
      expect(observed.fold!.state, DisplayFeatureState.postureFlat);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final type in [DisplayFeatureType.hinge, DisplayFeatureType.fold]) {
    testWidgets('engine $type takes precedence without losing any features', (
      tester,
    ) async {
      late MediaQueryData observed;
      final data = MediaQueryData(
        size: const Size(800, 600),
        displayFeatures: [
          DisplayFeature(
            bounds: const Rect.fromLTRB(400, 0, 400, 600),
            type: type,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      await tester.pumpWidget(
        MediaQuery(
          data: data,
          child: SplitScreen(
            child: Builder(
              builder: (context) {
                observed = MediaQuery.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(native.calls, ['listen']);
      await native.send(snapshot());
      await tester.pump();
      expect(observed, same(data));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.calls, ['listen', 'cancel']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
  testWidgets('Android passes ambient MediaQuery through without observation', (
    tester,
  ) async {
    const data = MediaQueryData(size: Size(800, 600));
    late MediaQueryData observed;
    await tester.pumpWidget(
      MediaQuery(
        data: data,
        child: SplitScreen(
          child: Builder(
            builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(observed, same(data));
    expect(native.calls, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('nullable child starts and stops observation only when needed', (
    tester,
  ) async {
    Widget app(Widget? child) => MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: SplitScreen(child: child),
    );
    await tester.pumpWidget(app(null));
    await tester.pump();
    expect(native.calls, isEmpty);
    await tester.pumpWidget(app(const SizedBox()));
    await tester.pump();
    expect(native.calls, ['listen']);
    await tester.pumpWidget(app(null));
    await tester.pump();
    expect(native.calls, ['listen', 'cancel']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  testWidgets('geometry arriving before new MediaQuery metrics is retained', (
    tester,
  ) async {
    late MediaQueryData observed;
    Widget app(Size size) => MediaQuery(
      data: MediaQueryData(size: size),
      child: SplitScreen(
        child: Builder(
          builder: (context) {
            observed = MediaQuery.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(app(const Size(800, 600)));
    await tester.pump();
    expect(native.calls, ['listen']);
    await native.send(snapshot());
    await tester.pump();
    expect(observed.fold, isNotNull);
    await native.send(
      snapshot(
        width: 600,
        height: 800,
        features: [
          {
            'left': 0,
            'top': 390,
            'right': 600,
            'bottom': 410,
            'state': 'halfOpened',
          },
        ],
      ),
    );
    await tester.pump();
    expect(observed.fold, isNull);
    await tester.pumpWidget(app(const Size(600, 800)));
    expect(observed.fold!.bounds, const Rect.fromLTRB(0, 390, 600, 410));
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(native.calls, ['listen', 'cancel']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
