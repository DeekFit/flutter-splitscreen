## 2.0.0-dev.1

* `TwoPane` automatically consumes native iPhone Duo divisions with existing
  call sites. The root `SplitScreen` wrapper is optional for custom MediaQuery
  consumers. Nested layouts respect transformed geometry and share observation.
* Preserve visible pane and nested Navigator state when late geometry switches
  between one and two panes.
* **Breaking:** Requires Dart >=3.10.0 <4.0.0 and Flutter >=3.38.0. iOS deployment
  target is 15.0; compiling the plugin requires Xcode 27.1 and the Duo SDK.
  Duo behavior is gated on iOS 27.1. CocoaPods supports Flutter 3.38+; SwiftPM
  uses the Flutter 3.44+ packaging baseline.
* **Breaking:** Operational sensor errors are now observable instead of being
  swallowed. Observation is lazy, shared, replaying, and ends on last cancel;
  readings are cleared before reconnecting. Missing plugins remain empty/false.
* Add native iOS angle observation and active division-region folds, the nullable
  `SplitScreen` MediaQuery wrapper, and the hinge-only-compatible `.fold` getter.
* Preserve child and Router state when initial or resized geometry arrives.
  Refresh native layout through callbacks instead of continuous frame polling;
  retry only while waiting for attachment and skip angle-only region queries.
* Preserve Android, public `DualScreenInfo` call sites and channel names,
  numeric angle ranges, and `TwoPane` override rules. Correct documentation for
  existing zero-area fold behavior.
* Update the example for scene lifecycle, resizing, and independent live angles.
* Add isolated Dart transport/widget tests and wired native XCTest fixtures for
  providers, geometry, transport, lifecycle, and bounded capability initialization.
* Windows validation does not verify Swift builds or native runtime support.
  Follow `doc/ios-validation.md` before claiming either. No release tag or
  publishing is part of this change; the tag-triggered workflow is unchanged.

## 1.0.5
* Forked from Microsoft's dual_screen project
* Updated to latest Android, AGP, and Kotlin versions to support newer versions of Flutter
* Re-published on pub.dev as split_screen

## 1.0.4

* Updated AGP to 7 and kotlin to 1.7

## 1.0.3

* TwoPane no longer removes display features from child panes. This allows child panes to know if the device has display features.
* TwoPane has a new property called `allowedOverrides`. This allows for finer control over what layouts are possible on foldable devices.
* Extension method `hinge` was added to MediaQueryData. This allows developers to use `MediaQuery.of(context).hinge` for logic related to the hinge.

## 1.0.2+2

* Removed requirement for flutter 2.11

## 1.0.2

* Added compatibility with current flutter stable channel

## 1.0.1

* Added TwoPane widget

## 1.0.0+3

* Updated Readme

## 1.0.0+2

* `DualScreenInfo.hingeAngleEvents` now caches the last value
* Updated Readme

## 1.0.0

* `DualScreenInfo.hingeAngleEvents`: Broadcast stream of events from the device hinge angle sensor
* `DualScreenInfo.hasHingeAngleSensor`: Future returning true if the device has a hinge angle sensor
