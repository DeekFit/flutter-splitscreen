# Flutter Split Screen

Adaptive two-pane layouts and hinge-angle readings for Flutter apps on Android
foldables and iPhone Duo. The same `TwoPane` code also works on phones, tablets,
desktops, and web.

## Features

* Automatically position panes on opposite sides of a separating hinge or fold.
* Use horizontal, vertical, or single-pane layouts when there is no separating
  display feature, with configurable proportions and pane priority.
* On iPhone Duo, automatically use active division regions, including their
  reported margins. No app wrapper or platform checks are required for `TwoPane`.
* Preserve visible pane and Navigator state when folding, rotating, or resizing.
* Read hinge angles independently of layout, including supplied flat and closed
  readings. Concurrent listeners share native observation and receive its latest
  reading; observation stops when the last listener cancels.
* Support RTL pane ordering, padding, and zero-width or zero-height fold seams.

## Supported platforms

| Platform | TwoPane layout | Hinge-angle readings |
| --- | --- | --- |
| Android | Uses Flutter's hinge/fold display features | Available when the device provides a hinge sensor |
| iPhone Duo, iOS 27.1+ | Automatically uses active division regions | Available through the Duo API |
| Other iPhones, iOS 15+ | Uses the app's normal layout policy | No Duo readings |
| Web, Windows, macOS, Linux | Uses the app's normal policy and any supplied display features | No native sensor integration |

Native iOS support has been tested in Duo and ordinary-iPhone simulators.
Physical-device sensor accuracy has not been verified. A display feature does
not by itself establish whether a hinge-angle sensor is available.

## Requirements

* Flutter 2.10 or later and Dart 2.12 or later.
* iOS deployment target 15.0 or later.
* To build for iOS, Xcode 27.1 with the Duo SDK is required, including when the
  app runs on an older iPhone. Duo APIs are guarded at runtime for iOS 27.1+.
* CocoaPods and Swift Package Manager are supported. SwiftPM requires Flutter
  3.44 or later.

## Installation

```yaml
dependencies:
  split_screen: ^2.0.0
```

Then run `flutter pub get`.

## TwoPane

```dart
import 'package:flutter/material.dart';
import 'package:split_screen/split_screen.dart';

void main() => runApp(const MaterialApp(home: AdaptiveHome()));

class AdaptiveHome extends StatelessWidget {
  const AdaptiveHome({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => TwoPane(
    paneProportion: 0.35,
    panePriority: MediaQuery.of(context).size.width >= 600
        ? TwoPanePriority.both
        : TwoPanePriority.start,
    startPane: const Scaffold(
      body: Center(child: Text('Items')),
    ),
    endPane: const Scaffold(
      body: Center(child: Text('Details')),
    ),
  );
}
```

This shows one pane on a narrow phone and 35%/65% columns on a wide screen.
When a hinge or fold separates the available area, each pane occupies one side
of the feature instead. Horizontal divisions produce top/bottom panes.

| Parameter | Purpose |
| --- | --- |
| `startPane`, `endPane` | The two child widgets |
| `paneProportion` | Fraction assigned to the start pane; defaults to `0.5` |
| `panePriority` | Show `both`, `start`, or `end`; defaults to `both` |
| `direction` | Axis when there is no separating feature; defaults to horizontal |
| `textDirection`, `verticalDirection` | Pane ordering, as in `Flex` |
| `padding` | Insets between this widget and its full-view `MediaQuery` bounds |
| `allowedOverrides` | Which layout choices a separating feature may override |

By default, a separating feature overrides direction, proportion, and priority.
You can restrict those overrides, for example to keep a particular route in a
single pane. Disabling proportion overrides also disables alignment to the
feature's full bounds.

`TwoPane` uses full-view display-feature coordinates. If it sits below an app
bar or inside other insets, supply those offsets through `padding` so the panes
align with the physical division. This applies on all platforms. Each pane's
`MediaQuery` padding and insets are adjusted for its position.

## Hinge angles

```dart
final supported = await DualScreenInfo.hasHingeAngleSensor;

final subscription = DualScreenInfo.hingeAngleEvents.listen(
  (double degrees) => debugPrint('Hinge angle: $degrees'),
  onError: (Object error) => debugPrint('Sensor error: $error'),
);

// Cancel when the consumer is disposed.
await subscription.cancel();
```

Readings are in degrees and are not clamped to an iPhone-specific range. Devices
without a supported sensor produce no readings, rather than a synthetic zero.
Missing native plugins return false capability and an empty stream.
Initialization, stream, and cancellation errors are propagated to the caller.

On iOS, capability initialization can wait up to two seconds for the attached
view. A false result while the view is unavailable can be queried again later.
Use active display features for pane layout; an angle reading is not required
for `TwoPane` to split.

## Custom display-feature layouts

If your own widgets read `MediaQuery.displayFeatures` outside `TwoPane`, use the
optional `SplitScreen` widget to expose native Duo divisions to that subtree:

```dart
MaterialApp(
  builder: (context, child) => SplitScreen(child: child),
  home: const MyCustomLayout(),
);
```

It preserves the other `MediaQuery` metrics and gives engine-provided hinges
and folds precedence. Nested layouts do not reinsert native geometry after an
ancestor has transformed or removed display features. On other platforms it
passes the child through unchanged.

`MediaQuery.of(context).hinge` returns the first physical hinge feature.
`MediaQuery.of(context).fold` returns the first fold feature. These getters are
layout helpers, not sensor-capability checks.

## Upgrading from 1.x

Existing `TwoPane` constructors and `DualScreenInfo` calls are unchanged. Update
the dependency to get automatic iPhone Duo layout support. Apps that explicitly
restrict `allowedOverrides` continue to control their own layout policy.

The Dart and Flutter minimums are unchanged from 1.x. iOS builds require the
Duo SDK; the newer SwiftPM integration requires Flutter 3.44+. Sensor errors that
were previously swallowed are now reported, so handle errors on futures, stream
subscriptions, and subscription cancellation.

## Example and tests

Run the [example](example/) with `flutter run` on a connected device or simulator.
It demonstrates automatic pane layout, capability detection, and live angles.
The example's iOS scene-lifecycle integration uses Flutter 3.41+ engine APIs;
this requirement applies to that iOS example, not to the library's Android or
Dart code.

```sh
flutter test
flutter analyze
cd example
flutter test
flutter analyze
```

Native XCTest fixtures can be run on a Mac with an installed Flutter SDK and
an available simulator:

```sh
ruby tool/native_tests.rb FLUTTER_SDK_PATH SIMULATOR_UDID cocoapods
ruby tool/native_tests.rb FLUTTER_SDK_PATH SIMULATOR_UDID swiftpm
```

The CocoaPods fixture runner requires CocoaPods and the `xcodeproj` Ruby gem.

## License

Forked from Microsoft's `dual_screen` package. Distributed under the [MIT
license](LICENSE).
