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

For iOS, build with Xcode 27.1 and the Duo SDK. The deployment target is iOS 15;
Duo functionality requires iOS 27.1 or later. See the package
[README](../README.md) for supported platforms and requirements.
