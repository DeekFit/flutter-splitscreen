# Split Screen example

Run `flutter pub get` then `flutter run` from this directory. The root
`MaterialApp.builder` installs `SplitScreen`. The example keeps a stable capability
Future and angle stream, displays live readings independently of fold layout,
and shows both panes at widths >=600 logical pixels. Narrow layouts show the
start pane unless an active separating display feature overrides the priority.

The iOS target uses the scene lifecycle, iOS 15 deployment settings, and the
existing Main/LaunchScreen storyboards. It allows portrait and landscape and
participates in resizable layouts. Build with Xcode 27.1 and the Duo SDK;
Duo APIs run only on iOS 27.1+. See the
[Mac validation checklist](../doc/ios-validation.md) for CocoaPods (Flutter
3.38) and SwiftPM (Flutter 3.44+) setup, native fixture execution, and simulator
limitations. Native builds remain unverified from Windows.
