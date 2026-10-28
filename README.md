# Flutter Split Screen

**note**
This project has been forked from the Microsoft DualScreen project in order to keep it up to date with the latest Flutter / Android requirements. The information below is otherwise unchanged, unless necessary.

This contains Microsoft's offerings to streamline foldable and dual-screen development using Flutter. This fork adds native iPhone Duo support alongside Android. The layout widgets also work on ordinary phones, tablets, desktops, and web.

Flutter already has support for foldable and dual-screen devices in the form of [MediaQuery Display Features](https://docs.microsoft.com/en-us/dual-screen/flutter/mediaquery). In addition to that, this plugin offers:

- The [TwoPane widget](#twopane-widget), which relies on display features coming from MediaQuery.
- Access to the [hinge angle sensor data](#hinge-angle-sensor), which for performance concerns, was not included in MediaQuery.
- Automatic iPhone Duo division-region support in `TwoPane`, without an application-level wrapper or platform checks.

## Installation and requirements

```yaml
dependencies:
  split_screen: ^2.0.0
```

Run `flutter pub get`, then import `package:split_screen/split_screen.dart`.
The package retains its Dart 2.12+ and Flutter 2.10+ minimums.

| Platform | Layout and sensor support |
| --- | --- |
| Android | Uses Flutter's hinge/fold display features; angle readings require a device hinge sensor |
| iPhone Duo, iOS 27.1+ | Automatically uses active division regions and supports native hinge-angle readings |
| Other iPhones, iOS 15+ | Normal layout policy, with no Duo readings |
| Web, Windows, macOS, Linux | Layout widgets and supplied display features; no native angle-sensor integration |

Building for iOS requires Xcode 27.1 with the Duo SDK and a deployment target of
iOS 15 or later. Duo APIs are guarded at runtime for iOS 27.1+. CocoaPods and
Swift Package Manager are supported; the newer SwiftPM integration requires
Flutter 3.44+. These iOS requirements do not apply to Android or web builds.
iOS support has been tested in simulators; physical-device sensor accuracy has
not been verified.

# TwoPane Widget

This layout has two child panes, which can be shown side-by-side, above-and-below, or a single pane can be prioritized. The relative size of the two pane widgets can be adjusted proportionally; and on dual-screen devices the boundary snaps to the hinge area.

On iPhone Duo, existing `TwoPane` calls automatically align with active division
regions, including their full reported margins. A horizontal division produces
top/bottom panes. With no separating feature, the widget follows the app's normal
width and pane-priority policy. Layout does not depend on an angle reading, and
visible pane and Navigator state survive geometry changes.

## TwoPane API

```dart
class TwoPane {
  const TwoPane({
    required Widget startPane,
    required Widget endPane,
    double paneProportion,
    TwoPanePriority panePriority,
    Axis direction,
    TextDirection? textDirection,
    VerticalDirection verticalDirection,
    EdgeInsets padding,
    Set<TwoPaneAllowedOverrides> allowedOverrides,
  });
}
```

Properties of TwoPane:

- `startPane` - Start pane, which can sit on the left for left-to-right layouts, or at the top for top-to-bottom layouts. If `panePriority` is `start` and there is no hinge, this is the only visible pane.
- `endPane` - End pane, which can sit on the right for left-to-right layouts, or at the bottom for top-to-bottom layouts. If `panePriority` is `end`, and there is no hinge, this is the only visible pane.
- `paneProportion` - Proportion of the screen occupied by the start pane. The end pane takes over the rest of the space. A value of 0.5 will make the two panes equal. This property is ignored for displays with a hinge, in which case each pane takes over one screen.
- `panePriority` - Whether to show only one the start pane, end pane, or both. This property is ignored for displays with a hinge, in which case `both` panes are visible.
- `direction` - Whether to stack the two panes verticaly or horizontaly, similar to [Flex direction](https://api.flutter.dev/flutter/widgets/Flex/direction.html). This property is ignored for displays with a hinge, in which case the direction is `horizontal` for vertical hinges and `vertical` for horizontal hinges.
- `textDirection` - When panes are laid out horizontally, this determines which one goes on the left. Behaves the same as [Flex textDirection](https://api.flutter.dev/flutter/widgets/Flex/textDirection.html)
- `verticalDirection` - When panes are laid out vertically, this determines which one goes at the top. Behaves the same as [Flex verticalDirection](https://api.flutter.dev/flutter/widgets/Flex/verticalDirection.html)
- `padding` - The padding between TwoPane and the edges of the screen. If there is spacing between TwoPane and the root MediaQuery, `padding` is used to correctly align the two panes to the hinge.
- `allowedOverrides` - The parameters that TwoPane is allowed to override when a separating display feature is found. By default, it contains `paneProportion`, `direction` and `panePriority`, allowing all possible overrides.

> Most of the parameters provided to TwoPane are ignored when the device has a hinge. This means that you can focus on how the layout works on large screens like tablets and desktops, while also having it adapt well to the dual-screen form factor by default.

The same override rules apply to separating folds, including zero-width or
zero-height seams. Explicitly limiting `allowedOverrides` retains the app's
chosen policy; disabling proportion overrides also disables alignment to the
feature's full bounds. If `TwoPane` sits below an app bar or inside other insets,
use `padding` to provide its offset from the full-view `MediaQuery` bounds on
all platforms.

## TwoPane example

```dart
Widget build(BuildContext context) {
  return TwoPane(
    startPane: _widgetA(),
    endPane: _widgetB(),
    paneProportion: 0.3,
    panePriority: MediaQuery.of(context).size.width > 500 ? TwoPanePriority.both : TwoPanePriority.start,
  );
}
```

This sample code produces the results at the beginning of this article:

- On **iPhone Duo**, an active separating division places widget A and widget B on opposite sides of the division.

- On **Surface Duo**, widget A and widget B both take one screen.
  ![Flutter TwoPaneView on Surface Duo](https://github.com/microsoft/flutter-dualscreen/blob/main/images/twopaneview-surfaceduo-simple.png)
- On a **tablet** or **desktop**, widget A takes 30% of the screen while widget B takes the remaining 70%.
  ![Flutter TwoPaneView on desktop](https://github.com/microsoft/flutter-dualscreen/blob/main/images/twopaneview-desktop-simple.png)
- On a **small phone** which is less than 500 logical pixels wide, only widget A is visible.
  ![Flutter TwoPaneView on a candybar phone](https://github.com/microsoft/flutter-dualscreen/blob/main/images/twopaneview-phone-simple.png)

## Custom display-feature layouts

`TwoPane` handles native Duo geometry internally. If your own widgets read
`MediaQuery.displayFeatures` outside `TwoPane`, use the optional `SplitScreen`
wrapper to expose Duo divisions to that subtree:

```dart
MaterialApp(
  builder: (context, child) => SplitScreen(child: child),
  home: const MyCustomLayout(),
);
```

It preserves other MediaQuery metrics and gives engine-provided hinges and
folds precedence. Nested layouts respect their ancestor's transformed or
filtered display features. `MediaQuery.of(context).hinge` still returns physical
hinges only; the new `.fold` getter returns the first fold feature.

# Hinge angle sensor

Foldable and dual-screen devices have a hinge between the two moving parts of the screen. Some devices expose a sensor reporting the angle between the parts of the screen. For example, when these parts lay flat to form a continuous surface, the hinge angle reports a 180 deg angle.

> The hinge angle is used to determine the [device posture](https://developer.android.com/guide/topics/ui/foldables#postures). If you're looking to write code that depends on the device posture, we recommend using the functionality provided by [MediaQuery Display Features](https://docs.microsoft.com/en-us/dual-screen/flutter/mediaquery) instead.

## Hinge angle API

To use this plugin, add `split_screen` as a dependency in your pubspec.yaml file.

This will allow you to import DualScreenInfo `import 'package:split_screen/split_screen.dart';`

DualScreenInfo exposes 2 static properties:

- `hingeAngleEvents`: Broadcast stream of events from the device hinge angle sensor. If the device is not equipped with a hinge angle sensor, the stream produces no events.
- `hasHingeAngleSensor`: Future returning true if the device has a hinge angle sensor. Do not infer sensor availability from `MediaQuery.displayFeatures` or `MediaQuery.hinge`; layout and angle reporting are independent.

Angle observation is lazy and shared. New concurrent listeners receive the
latest reading, and native observation stops after the final cancellation.
Supplied flat and closed readings are retained without clamping Android angles
to an iPhone-specific range. Missing plugins return false capability and empty
streams; operational errors reach the capability future, stream listener, or
cancellation future. On iOS, capability initialization can wait up to two seconds
for attachment and can be queried again if the view was initially unavailable.

## Hinge angle example

```dart
import 'package:split_screen/split_screen.dart';

final subscription = DualScreenInfo.hingeAngleEvents.listen((double hingeAngle) {
  print(hingeAngle);
}, onError: (Object error) {
  print(error);
});

DualScreenInfo.hasHingeAngleSensor.then((bool hasHingeSensor) {
  print(hasHingeSensor);
}, onError: (Object error) {
  print(error);
});

// When the consumer is disposed, call: await subscription.cancel();
```

## Testing

Examples on how to mock the hinge angle or display features can be found in the [test](https://github.com/microsoft/flutter-dualscreen/tree/main/test) folder.

Testing the hinge angle sensor functionality can be done using the [Surface Duo emulator](https://docs.microsoft.com/en-us/dual-screen/android/emulator/get-started) or one of the [foldable emulators available in Android Studio](https://developer.android.com/guide/topics/ui/foldables#emulators). Both emulators provide a hinge angle virtual sensor. The Surface Duo emulator provides two separate screens.

![Surface Duo Emulator Hinge Sensor](https://github.com/microsoft/flutter-dualscreen/blob/main/images/emulator_hinge_angle.jpg)

For iOS, run the [example](example/) on an iPhone Duo simulator with iOS 27.1+.
The example's iOS scene-lifecycle integration uses Flutter 3.41+ engine APIs;
that requirement applies to the iOS example rather than the library's Dart or
Android code. Use `flutter run -d SIMULATOR_UDID` from the example directory.

Package tests and native XCTest fixtures can be run with:

```sh
flutter test
flutter analyze
ruby tool/native_tests.rb FLUTTER_SDK_PATH SIMULATOR_UDID cocoapods
ruby tool/native_tests.rb FLUTTER_SDK_PATH SIMULATOR_UDID swiftpm
```

The native fixture runner uses an installed Flutter SDK and requires CocoaPods
and the `xcodeproj` Ruby gem for the CocoaPods path.

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
