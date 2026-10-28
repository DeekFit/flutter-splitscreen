/// Copyright (c) Microsoft Corporation.
/// Licensed under the MIT License.

import 'package:flutter/services.dart';
import 'native_event_stream.dart';

class DualScreenInfo {
  static const _hingeInfoMethodChannel = MethodChannel(
    'com.microsoft.flutterdualscreen/hinge_info',
  );
  static final _hingeAngleEvents = NativeEventStream<double>(
    'com.microsoft.flutterdualscreen/hinge_angle',
    (value) => value is num && value.isFinite ? value.toDouble() : null,
  );

  /// Shared, replaying device hinge readings in degrees, without range clamping.
  /// Observation starts with the first listener and stops with the last.
  /// Missing plugins produce an empty stream. Operational errors reach listeners
  /// or the Future returned by subscription cancellation.
  static Stream<double> get hingeAngleEvents => _hingeAngleEvents;

  /// Whether the attached view hierarchy supplies a hinge angle sensor.
  /// Capability-query failures, including missing plugins, return false.
  /// iOS can wait up to two seconds for initial attachment and data.
  static Future<bool> get hasHingeAngleSensor async {
    try {
      return await _hingeInfoMethodChannel.invokeMethod<bool>(
            'hasHingeAngleSensor',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
