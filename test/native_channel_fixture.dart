import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Each fixture owns its receiver and native-call history.
class NativeChannelFixture {
  NativeChannelFixture(this.name) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      calls.add(call.method);
      return handler?.call(call);
    });
  }
  final String name;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  Future<Object?> Function(MethodCall)? handler;
  static const codec = StandardMethodCodec();
  Future<void> send(Object? value) =>
      envelope(codec.encodeSuccessEnvelope(value));
  Future<void> end() => envelope(null);
  Future<void> envelope(ByteData? message) async {
    await messenger.handlePlatformMessage(name, message, (_) {});
  }

  void dispose() {
    messenger.setMockMethodCallHandler(MethodChannel(name), null);
  }
}

Future<void> flushChannels() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
