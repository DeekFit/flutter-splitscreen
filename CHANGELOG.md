## 2.0.0

* Add iPhone Duo layout and hinge-angle support on iOS 27.1+, with an iOS 15
  deployment target and fallback on ordinary iPhones and older runtimes.
* Automatically align existing `TwoPane` layouts with active Duo divisions;
  no application-level wrapper is required. Preserve visible pane and nested
  Navigator state through geometry and single-pane/two-pane transitions.
* Add the optional `SplitScreen` wrapper for custom MediaQuery consumers and
  the `.fold` getter alongside the existing `.hinge` getter.
* Support iOS integration through CocoaPods and Swift Package Manager.
* Share native observations, replay the latest readings to concurrent listeners,
  and stop observation after the final cancellation. Keep angle reporting
  independent of layout and preserve supplied flat and closed readings.
* Retain the Dart 2.12+ and Flutter 2.10+ package minimums from 1.x. iOS
  compilation requires Xcode 27.1 with the Duo SDK; the newer SwiftPM integration
  requires Flutter 3.44+.
* Preserve nonthrowing capability queries: `hasHingeAngleSensor` returns false
  on query failures, including missing plugins. Angle-stream operational errors
  remain asynchronous stream or cancellation-future errors; missing plugins
  produce empty streams.
* Preserve valid division geometry during foreground inactivity and background
  suspension, refreshing it on resume without an intermediate empty layout.

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
