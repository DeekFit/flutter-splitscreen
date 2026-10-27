# Flutter Split Screen

`split_screen` provides `TwoPane`, hinge angle readings, and an optional iOS
`SplitScreen` wrapper. Forked from Microsoft's `dual_screen` package. The existing
Android implementation and Microsoft-prefixed channel names remain unchanged.

This `duo` branch is a **2.0.0-dev.1 development build**. Dart behavior is tested on
Windows. Native Swift compilation, packaging, and device/runtime behavior remain
unverified until the [Mac validation checklist](doc/ios-validation.md) passes.
Nothing has been tagged or published.

## Toolchains

| Component | Minimum / supported validation combination |
| --- | --- |
| Dart | >=3.10.0 <4.0.0 |
| Flutter with CocoaPods | 3.38+; validate the 3.38 baseline on Mac |
| Flutter with SwiftPM | 3.44+ (current Flutter plugin packaging guide) |
| iOS deployment target | 15.0 |
| Native compilation | Xcode 27.1 with the Duo SDK |
| Duo APIs at runtime | iOS 27.1+, guarded with availability checks |

Ordinary iPhones and older supported iOS runtimes return no Duo readings or
plugin folds. Android continues to use its existing sensor and engine display
features. Other platforms, including web, can use `TwoPane` with their ambient
`MediaQuery`; the iOS wrapper passes them through unchanged.

## Install and wrap the app

Add `split_screen` to your dependencies, then place the wrapper directly in
`MaterialApp.builder`, above navigators and full-view layouts:

```dart
import 'package:flutter/material.dart';
import 'package:split_screen/split_screen.dart';

MaterialApp(
  builder: (context, child) => SplitScreen(child: child),
  home: const MyHome(),
);
```

`SplitScreen({required Widget? child})` renders an empty widget for null and does
not start observation. On native iOS it augments the **ambient** `MediaQuery`
without replacing other metrics, padding, scaling, or display features. An
engine-provided hinge or fold takes precedence over plugin folds. Resizing clears
stale plugin geometry until a snapshot matching the new viewport arrives. Initial
empty results are provisional; later geometry rebuilds consumers. The wrapper
preserves child and Router state across these updates.

`MediaQuery.of(context).fold` returns the first fold. The existing `.hinge` getter
continues to return hinge features only. Do not use either getter as a substitute
for querying angle-sensor capability.

## TwoPane

```dart
TwoPane(
  startPane: const StartPane(),
  endPane: const EndPane(),
  paneProportion: 0.5,
  panePriority: MediaQuery.sizeOf(context).width >= 600
      ? TwoPanePriority.both
      : TwoPanePriority.start,
)
```

Without a separating feature, `direction`, `paneProportion`, and `panePriority`
control the layout. A separating feature normally overrides them to put both
panes on opposite sides of its full bounds. `allowedOverrides` retains its
existing rules and lets callers disable individual overrides. RTL and
`verticalDirection` determine pane order. Use `padding` to account for spacing
between the widget and the full-view `MediaQuery`.

A zero-width vertical fold or zero-height horizontal fold can separate panes if
it spans the viewport in the other direction and lies strictly inside the split
axis. `TwoPane` behavior is unchanged; its earlier zero-area documentation was
incorrect. Padding and insets are adjusted for each pane.

## iOS fold layout and angles

Layout queries only **active `.division` reserved regions**, explicitly filters
`isActive`, and preserves their complete reported frames, including interactive
margins. It does not request inactive regions or turn camera occlusions into
folds. A flat device normally has no active division to avoid; the example then
chooses both panes at widths >=600 logical pixels and the start pane otherwise.
An active separating region still applies the existing override rules.

Angle reporting is independent of layout. `UIHingeInteraction` provides readings
in radians, converted to degrees without synthesized readings or device-specific
thresholds. Partially open status maps to half-opened posture; fully open maps
to flat; other statuses map to unknown. Region activity alone determines whether
layout publishes a fold. Closed and flat angle readings are retained when the
hierarchy supplies them. No sensor precision, callback frequency, or physical
accuracy is promised.

The observer is transparent and noninteractive, attached to the registrar's
Flutter view. It uses that view's scene and coordinates; there is no global
screen/window selection. Capability waits for the initial callback, up to two
seconds. An unavailable hierarchy returns false for that request, without caching
it permanently. Detachment and backgrounding pause native observation and clear
fold data; existing subscriptions resume when the hierarchy becomes usable.
Teardown removes interactions, observers, and pending callbacks.

Layout, safe-area, hinge, and scene callbacks refresh native geometry; a second
layout pass lets region changes settle after a hinge update. Attached idle views
have no continuous frame timer. A lightweight retry runs only while waiting for a
usable Flutter hierarchy, and region queries run only for layout subscribers.

Additional scenes, outer-display content, and camera-region layout are outside
this iteration. The example adopts the scene lifecycle with the existing Main
and LaunchScreen storyboards and supports rotation and resizing.

## Hinge angle API

```dart
final supported = await DualScreenInfo.hasHingeAngleSensor;
final subscription = DualScreenInfo.hingeAngleEvents.listen(
  (degrees) => debugPrint('$degrees'),
  onError: (Object error) => debugPrint('Sensor error: $error'),
);
// When the consumer is disposed:
await subscription.cancel();
```

The existing public call sites and channels
`com.microsoft.flutterdualscreen/hinge_info` and
`com.microsoft.flutterdualscreen/hinge_angle` are preserved. Finite numeric samples
become doubles; invalid/null samples are ignored. The Android angle range is not
clamped to an iPhone-specific range.

Subscriptions are lazy and shared, replaying the latest value to concurrent
listeners. Native observation stops after the final cancellation and discards
stale readings. Reconnect waits for prior cancellation. Missing plugins produce
empty streams (and false capability); genuine method, setup, event, and
cancellation failures remain observable. This receiver catches activation and
cancellation failures directly without replacing any global error handlers.
The wrapper reports its operational channel errors through Flutter's existing
error reporting mechanism.

The internal `split_screen/display_features` event channel sends snapshots:

```text
{width, height, features: [{left, top, right, bottom, state}]}
```

All dimensions are finite logical coordinates relative to the Flutter viewport.
`state` is `halfOpened`, `flat`, or `unknown`. Zero-width/height seams are valid.
Native snapshots are coalesced with a 0.01 logical pixel tolerance. An empty
feature list clears previous folds.

## Validation

```sh
flutter pub get
flutter test
flutter analyze
flutter test --platform chrome test/split_screen_web_test.dart
flutter pub publish --dry-run
cd example
flutter pub get
flutter test
flutter analyze
```

Tests exercise isolated stream lifetimes and native calls, errors, replay,
concurrency, reconnection, numeric decoding, late geometry, resize/removal,
engine precedence, null children, Android/web passthrough, zero-area seams, RTL,
padding, and overrides. See the [Windows validation record](doc/windows-validation.md),
including the local browser-test workaround and dry-run warning. Windows cannot
establish native compilation or runtime support. See
[Mac checks and wired XCTest fixtures](doc/ios-validation.md).

Implementation references: [Apple hinge interaction](https://developer.apple.com/documentation/uikit/uihingeinteraction),
[Apple reserved regions](https://developer.apple.com/documentation/uikit/uiview/reservedregion),
[Flutter SwiftPM packaging](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors),
and [Flutter scene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.

<!-- ## Special thanks -->

<!-- The [split_screen](https://pub.dev/packages/split_screen) package was previously owned by [Built to Roam](https://pub.dev/publishers/builttoroam.com/) and it initially offered a way to know if your app is running on a dual screen device and if it is spanned across both screens or not. We would like to thank [Nick Randolph](https://github.com/nickrandolph), [Michael Bui](https://github.com/MaikuB) and [Brett Lim](https://github.com/Brett09) for transferring ownership of `split_screen` to Microsoft. -->
