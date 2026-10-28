import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen_example/main.dart';
import 'package:split_screen/split_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const info = MethodChannel('com.microsoft.flutterdualscreen/hinge_info');
  const angle = MethodChannel('com.microsoft.flutterdualscreen/hinge_angle');
  const layout = MethodChannel('split_screen/display_features');
  const codec = StandardMethodCodec();
  late List<String> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(angle, (call) async {
      calls.add(call.method);
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(info, null);
    messenger.setMockMethodCallHandler(angle, null);
    messenger.setMockMethodCallHandler(layout, null);
  });
  for (final supported in [true, false]) {
    testWidgets('sensor capability $supported', (tester) async {
      messenger.setMockMethodCallHandler(info, (call) async {
        expect(call.method, 'hasHingeAngleSensor');
        return supported;
      });
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(
        find.text('Hinge angle sensor exists: $supported'),
        findsOneWidget,
      );
      expect(calls, ['listen']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(calls, ['listen', 'cancel']);
    });
  }
  testWidgets('missing plugin falls back without errors', (tester) async {
    messenger.setMockMessageHandler(angle.name, (_) async => null);
    messenger.setMockMessageHandler(info.name, (_) async => null);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.text('Hinge angle sensor exists: false'), findsOneWidget);
  });
  testWidgets('live angle survives flat and closed readings and resizing', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(info, (_) async => true);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Second pane:'), findsNothing);
    for (final value in [123, 180, 0]) {
      await messenger.handlePlatformMessage(
        angle.name,
        codec.encodeSuccessEnvelope(value),
        (_) {},
      );
      await tester.pump();
      expect(
        find.text('Hinge angle is: ${value.toStringAsFixed(2)}'),
        findsOneWidget,
      );
    }
    tester.view.physicalSize = const Size(800, 500);
    await tester.pumpAndSettle();
    expect(find.textContaining('Second pane:'), findsOneWidget);
    expect(calls, ['listen']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls, ['listen', 'cancel']);
  });

  testWidgets('Duo example splits automatically without an app wrapper', (
    tester,
  ) async {
    final layoutCalls = <String>[];
    messenger.setMockMethodCallHandler(info, (_) async => true);
    messenger.setMockMethodCallHandler(layout, (call) async {
      layoutCalls.add(call.method);
      return null;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('Second pane:'), findsNothing);
    await messenger.handlePlatformMessage(
      layout.name,
      codec.encodeSuccessEnvelope({
        'width': 500,
        'height': 800,
        'features': [
          {
            'left': 230,
            'top': 0,
            'right': 270,
            'bottom': 800,
            'state': 'unknown',
          },
        ],
      }),
      (_) {},
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Second pane:'), findsOneWidget);
    expect(
      tester.getRect(find.byType(Scaffold)),
      const Rect.fromLTRB(0, 0, 230, 800),
    );
    // TwoPane owns its internal wrapper; the application has none above it.
    expect(
      find.ancestor(
        of: find.byType(TwoPane),
        matching: find.byType(SplitScreen),
      ),
      findsNothing,
    );
    expect(layoutCalls, ['listen']);
    expect(calls, ['listen']);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(layoutCalls, ['listen', 'cancel']);
    expect(calls, ['listen', 'cancel']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
