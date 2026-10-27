import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_screen/split_screen.dart';
import 'package:split_screen/src/native_event_stream.dart';
import 'native_channel_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const info = MethodChannel('com.microsoft.flutterdualscreen/hinge_info');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late NativeChannelFixture native;
  late NativeEventStream<double> stream;
  setUp(() {
    native = NativeChannelFixture('test/angles');
    stream = NativeEventStream<double>(
      native.name,
      (value) => value is num && value.isFinite ? value.toDouble() : null,
    );
  });
  tearDown(() async {
    await flushChannels();
    native.dispose();
    messenger.setMockMethodCallHandler(info, null);
  });

  for (final value in [true, false, null]) {
    test('capability decodes $value and verifies method', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(info, (call) async {
        expect(call.method, 'hasHingeAngleSensor');
        calls++;
        return value;
      });
      expect(await DualScreenInfo.hasHingeAngleSensor, value ?? false);
      expect(calls, 1);
    });
  }
  test('missing capability is false, operational errors propagate', () async {
    expect(await DualScreenInfo.hasHingeAngleSensor, false);
    messenger.setMockMethodCallHandler(
      info,
      (_) async => throw PlatformException(code: 'failed'),
    );
    await expectLater(
      DualScreenInfo.hasHingeAngleSensor,
      throwsA(isA<PlatformException>()),
    );
  });
  test('delayed capability can later become available', () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(info, (_) => ready.future);
    final result = DualScreenInfo.hasHingeAngleSensor;
    ready.complete(false);
    expect(await result, false);
    messenger.setMockMethodCallHandler(info, (_) async => true);
    expect(await DualScreenInfo.hasHingeAngleSensor, true);
  });
  test('lazy, shared, replaying, clears after last cancellation', () async {
    expect(native.calls, isEmpty);
    final first = <double>[];
    final second = <double>[];
    final a = stream.listen(first.add);
    await flushChannels();
    await native.send(270);
    final b = stream.listen(second.add);
    await flushChannels();
    expect(first, [270.0]);
    expect(second, [270.0]);
    expect(native.calls, ['listen']);
    await a.cancel();
    expect(native.calls, ['listen']);
    await native.send(360.5);
    expect(second, [270.0, 360.5]);
    await b.cancel();
    expect(native.calls, ['listen', 'cancel']);
    final fresh = <double>[];
    final c = stream.listen(fresh.add);
    await flushChannels();
    expect(fresh, isEmpty);
    await native.send(0);
    expect(fresh, [0.0]);
    await c.cancel();
    expect(native.calls, ['listen', 'cancel', 'listen', 'cancel']);
  });
  test(
    'numeric samples decode; invalid and nonfinite samples are ignored',
    () async {
      final values = <double>[];
      final sub = stream.listen(values.add);
      await flushChannels();
      for (final value in [
        null,
        '4',
        true,
        double.nan,
        double.infinity,
        -double.infinity,
        <Object?, Object?>{},
        -1,
        0,
        181.25,
        360,
      ]) {
        await native.send(value);
      }
      expect(values, [-1.0, 0.0, 181.25, 360.0]);
      await sub.cancel();
    },
  );
  test('missing activation closes empty and retries next listen', () async {
    messenger.setMockMethodCallHandler(MethodChannel(native.name), null);
    expect(await stream.toList(), isEmpty);
    native.dispose();
    native = NativeChannelFixture('test/angles');
    final sub = stream.listen((_) {});
    await flushChannels();
    expect(native.calls, ['listen']);
    await sub.cancel();
  });
  test(
    'setup error is observable without changing FlutterError handler',
    () async {
      native.handler = (call) async {
        if (call.method == 'listen') throw PlatformException(code: 'setup');
        return null;
      };
      await expectLater(stream.toList(), throwsA(isA<PlatformException>()));
      await flushChannels();
      expect(native.calls, ['listen', 'cancel']);
    },
  );
  test('native errors and malformed envelopes reach listeners', () async {
    final errors = <Object>[];
    final values = <double>[];
    final sub = stream.listen(values.add, onError: errors.add);
    await flushChannels();
    await native.envelope(
      NativeChannelFixture.codec.encodeErrorEnvelope(code: 'sensor'),
    );
    await native.envelope(ByteData(1));
    await native.send(180);
    expect(errors, [isA<PlatformException>(), isA<FormatException>()]);
    expect(values, [180.0]);
    await sub.cancel();
  });
  test(
    'cancellation failure reaches cancellation Future and permits reconnect',
    () async {
      native.handler = (call) async {
        if (call.method == 'cancel') throw PlatformException(code: 'cancel');
        return null;
      };
      final sub = stream.listen((_) {});
      await flushChannels();
      await expectLater(sub.cancel(), throwsA(isA<PlatformException>()));
      native.handler = null;
      final next = stream.listen((_) {});
      await flushChannels();
      await next.cancel();
      expect(native.calls, ['listen', 'cancel', 'listen', 'cancel']);
    },
  );
  test('reconnection waits for old native cancellation', () async {
    final cancelling = Completer<Object?>();
    native.handler = (call) async =>
        call.method == 'cancel' ? cancelling.future : null;
    final first = stream.listen((_) {});
    await flushChannels();
    final cancelled = first.cancel();
    final values = <double>[];
    final second = stream.listen(values.add);
    await flushChannels();
    expect(native.calls, ['listen', 'cancel']);
    cancelling.complete();
    await cancelled;
    await flushChannels();
    expect(native.calls, ['listen', 'cancel', 'listen']);
    await native.send(42);
    expect(values, [42.0]);
    await second.cancel();
  });
  test(
    'cancellation during activation serializes teardown and next listen',
    () async {
      final activating = Completer<Object?>();
      native.handler = (call) async =>
          call.method == 'listen' ? activating.future : null;
      final first = stream.listen((_) {});
      await flushChannels();
      final cancelled = first.cancel();
      final second = stream.listen((_) {});
      expect(native.calls, ['listen']);
      activating.complete();
      await cancelled;
      await flushChannels();
      expect(native.calls, ['listen', 'cancel', 'listen']);
      await second.cancel();
    },
  );
  test('end of stream never caches completion across subscriptions', () async {
    final first = stream.toList();
    await flushChannels();
    await native.send(90);
    await native.end();
    expect(await first, [90.0]);
    await flushChannels();
    final second = stream.toList();
    await flushChannels();
    await native.send(120);
    await native.end();
    expect(await second, [120.0]);
    await flushChannels();
    expect(native.calls, ['listen', 'cancel', 'listen', 'cancel']);
  });
  test(
    'public legacy angle channel is exercised on every observation',
    () async {
      final legacy = NativeChannelFixture(
        'com.microsoft.flutterdualscreen/hinge_angle',
      );
      for (final value in [123, 240]) {
        final values = <double>[];
        final sub = DualScreenInfo.hingeAngleEvents.listen(values.add);
        await flushChannels();
        await legacy.send(value);
        expect(values, [value.toDouble()]);
        await sub.cancel();
      }
      expect(legacy.calls, ['listen', 'cancel', 'listen', 'cancel']);
      legacy.dispose();
    },
  );
  test(
    'completion queues cleanup before an immediate replacement listener',
    () async {
      final barrier = Completer<Object?>();
      native.handler = (call) async =>
          call.method == 'cancel' ? barrier.future : null;
      final first = stream.listen((_) {});
      await flushChannels();
      await native.end();
      final values = <double>[];
      final second = stream.listen(values.add);
      await flushChannels();
      expect(native.calls, ['listen', 'cancel']);
      barrier.complete();
      await flushChannels();
      expect(native.calls, ['listen', 'cancel', 'listen']);
      await native.send(75);
      expect(values, [75.0]);
      await first.cancel();
      await second.cancel();
    },
  );

  test('cancelling before queued activation avoids a native listen', () async {
    final sub = stream.listen((_) {});
    await sub.cancel();
    expect(native.calls, isEmpty);
  });

  test('missing cancellation is harmless', () async {
    final sub = stream.listen((_) {});
    await flushChannels();
    native.messenger.setMockMessageHandler(native.name, (_) async => null);
    await sub.cancel();
    expect(native.calls, ['listen']);
  });
}
