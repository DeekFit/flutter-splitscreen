import 'dart:async';
import 'package:flutter/services.dart';
import 'async_compat.dart';

/// Lazy shared Flutter event-channel receiver with serialized native lifetime.
class NativeEventStream<T> extends Stream<T> {
  NativeEventStream(this.channel, this.decode, {BinaryMessenger? messenger})
      : _messenger = messenger;
  final String channel;
  final T? Function(Object?) decode;
  final BinaryMessenger? _messenger;
  BinaryMessenger get messenger =>
      // Binding.instance was nullable before Flutter 3.0.
      // ignore: unnecessary_non_null_assertion
      _messenger ?? ServicesBinding.instance!.defaultBinaryMessenger;
  static const _codec = StandardMethodCodec();
  _Observation<T>? _observation;
  Future<void>? _operations;

  @override
  bool get isBroadcast => true;

  Future<void> _enqueue(Future<void> Function() operation) {
    final result = (_operations ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _error, StackTrace _stack) {},
    );
    _operations = tail;
    ignoreFuture(
      tail.then((_) {
        if (identical(_operations, tail)) _operations = null;
      }),
    );
    return result;
  }

  @override
  StreamSubscription<T> listen(
    void Function(T)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    late StreamController<T> controller;
    late _Observation<T> observation;
    controller = StreamController<T>(
      sync: true,
      onListen: () {
        observation = _observation ??= _Observation<T>();
        observation.listeners.add(controller);
        final latest = observation.latest;
        if (latest is T) controller.add(latest);
        if (!observation.scheduled) {
          observation.scheduled = true;
          ignoreFuture(_enqueue(() => _start(observation)));
        }
      },
      onCancel: () {
        observation.listeners.remove(controller);
        if (observation.listeners.isNotEmpty) return null;
        if (identical(_observation, observation)) _observation = null;
        observation.latest = null;
        return _enqueue(() => _stop(observation));
      },
    );
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  Future<void> _invoke(String method) async {
    final reply = await messenger.send(
      channel,
      _codec.encodeMethodCall(MethodCall(method)),
    );
    if (reply == null) throw MissingPluginException();
    _codec.decodeEnvelope(reply);
  }

  Future<void> _start(_Observation<T> observation) async {
    if (observation.listeners.isEmpty) return;
    observation.active = true;
    try {
      messenger.setMessageHandler(channel, (message) async {
        if (observation.listeners.isEmpty || observation.finishing) return null;
        if (message == null) {
          _finish(observation);
          return null;
        }
        try {
          final value = decode(_codec.decodeEnvelope(message));
          if (value != null) {
            observation.latest = value;
            for (final listener in observation.listeners.toList()) {
              listener.add(value);
            }
          }
        } catch (error, stack) {
          for (final listener in observation.listeners.toList()) {
            listener.addError(error, stack);
          }
        }
        return null;
      });
      await _invoke('listen');
    } on MissingPluginException {
      observation.active = false;
      messenger.setMessageHandler(channel, null);
      _finish(observation);
    } catch (error, stack) {
      for (final listener in observation.listeners.toList()) {
        listener.addError(error, stack);
      }
      _finish(observation);
    }
  }

  void _finish(_Observation<T> observation) {
    if (observation.finishing) return;
    observation.finishing = true;
    // Queue teardown before making a replacement observation possible.
    final stopped = _enqueue(() => _stop(observation));
    if (identical(_observation, observation)) _observation = null;
    observation.latest = null;
    ignoreFuture(
      stopped.then<void>(
        (_) {
          for (final listener in observation.listeners.toList()) {
            ignoreFuture(listener.close());
          }
        },
        onError: (Object error, StackTrace stack) {
          for (final listener in observation.listeners.toList()) {
            listener.addError(error, stack);
            ignoreFuture(listener.close());
          }
        },
      ),
    );
  }

  Future<void> _stop(_Observation<T> observation) async {
    if (!observation.active) return;
    observation.active = false;
    messenger.setMessageHandler(channel, null);
    try {
      await _invoke('cancel');
    } on MissingPluginException {
      // An absent plugin has nothing to cancel.
    }
  }
}

class _Observation<T> {
  final listeners = <StreamController<T>>{};
  T? latest;
  bool scheduled = false;
  bool active = false;
  bool finishing = false;
}
