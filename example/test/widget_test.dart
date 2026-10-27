import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const info = MethodChannel('com.microsoft.flutterdualscreen/hinge_info');
  const angle = MethodChannel('com.microsoft.flutterdualscreen/hinge_angle');
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
}
