import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'display_features.dart';
import 'native_event_stream.dart';

/// Augments the ambient MediaQuery with native iOS folds.
/// Place at the root: `builder: (_, child) => SplitScreen(child: child)`.
/// Engine-provided hinge/fold features take precedence. Other platforms pass
/// through unchanged. A null child never starts native observation.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key, required this.child});
  final Widget? child;
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  static final _events = NativeEventStream<DisplayFeaturesSnapshot>(
    'split_screen/display_features',
    DisplayFeaturesSnapshot.decode,
  );
  StreamSubscription<DisplayFeaturesSnapshot>? _subscription;
  DisplayFeaturesSnapshot? _snapshot;
  Size? _viewport;
  bool get _enabled =>
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.iOS &&
      widget.child != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewport = MediaQuery.maybeOf(context)?.size;
    if (_viewport != viewport &&
        (viewport == null || !(_snapshot?.matches(viewport) ?? false))) {
      _snapshot = null;
    }
    _viewport = viewport;
    _observe();
  }

  @override
  void didUpdateWidget(SplitScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _observe();
  }

  void _observe() {
    if (_enabled && _subscription == null) {
      _subscription = _events.listen(
        (snapshot) {
          if (mounted) setState(() => _snapshot = snapshot);
        },
        onError: (Object error, StackTrace stack) {
          if (mounted) setState(() => _snapshot = null);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'split_screen',
              context: ErrorDescription('while observing iOS display features'),
            ),
          );
        },
      );
    } else if (!_enabled) {
      _cancel();
      _snapshot = null;
    }
  }

  void _cancel() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(
        subscription.cancel().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'split_screen',
              context: ErrorDescription(
                'while cancelling iOS display features',
              ),
            ),
          );
        }),
      );
    }
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child == null) return const SizedBox.shrink();
    final data = MediaQuery.maybeOf(context);
    if (!_enabled || data == null) return child;
    final snapshot = _snapshot;
    final usePluginFeatures =
        snapshot != null &&
        snapshot.matches(data.size) &&
        !data.displayFeatures.any(
          (feature) =>
              feature.type == DisplayFeatureType.hinge ||
              feature.type == DisplayFeatureType.fold,
        );
    // Keep this inherited widget in place even before the first snapshot or
    // while resizing. Inserting/removing it would recreate unkeyed child state.
    return MediaQuery(
      data: usePluginFeatures
          ? data.copyWith(
              displayFeatures: [...data.displayFeatures, ...snapshot.features],
            )
          : data,
      child: child,
    );
  }
}
