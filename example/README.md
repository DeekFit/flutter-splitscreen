# Split Screen example

Demonstrates automatic `TwoPane` layout, sensor capability detection, and live
hinge-angle readings. No application-level wrapper is required.

```sh
flutter pub get
flutter run -d DEVICE_ID
```

On an uninterrupted display, the example shows two panes at widths of at least
600 logical pixels and one pane on narrower screens. A separating hinge or
active Duo division automatically positions the panes on its opposite sides.

For the iOS example, use Flutter 3.41+ (for its scene-lifecycle engine APIs)
and Xcode 27.1 with the Duo SDK. The deployment target is iOS 15;
Duo functionality requires iOS 27.1 or later. See the package
[README](../README.md) for supported platforms and requirements.

All iOS hosts built with Xcode 27 must adopt UIScene. Flutter 3.41+ migrates
eligible hosts automatically; custom or older hosts need the manual steps in
Flutter's [UIScene migration guide](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate).
This example already uses that lifecycle. The package itself retains Dart 2.12+
and Flutter 2.10+ minimums for its cross-platform code and existing Android minimums.

`TwoPane` receives Duo divisions automatically. Custom MediaQuery consumers
outside it need a root `SplitScreen` wrapper. Duo divisions are folds, so custom
layouts must check both `DisplayFeatureType.fold` and `DisplayFeatureType.hinge`;
`.hinge` continues to mean a physical hinge. See the package README for an example.
