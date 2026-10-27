# iOS validation checklist

Native compilation and runtime behavior are **unverified on Windows**. A passing
Dart suite is not evidence of Duo hardware support. Complete this checklist on a
Mac before claiming native acceptance; keep command output and `.xcresult` files.
Do not create a release tag or publish the package during validation.

## Prerequisites and matrix

* Xcode 27.1 selected with `xcode-select`, including the Duo SDK and an iOS 27.1
  Simulator runtime. Run `xcodebuild -version` and `xcrun simctl list devices available`.
* Separate Flutter SDKs for 3.38 (CocoaPods) and 3.44 or later (SwiftPM).
  Record their exact `flutter --version` outputs. Do not treat a successful
  3.47 build as proof that the 3.38 baseline compiles.
* CocoaPods and its Ruby `xcodeproj` dependency (`gem install cocoapods` if needed).
* An ordinary iPhone simulator/device and an older supported iOS runtime for
  availability/fallback checks. Use the oldest runtime available to Xcode 27.1;
  if iOS 15 cannot run there, record that coverage gap explicitly.

Use an SDK path and a simulator UDID returned by `simctl` in the commands below.
The fixture dimensions are arbitrary test inputs, never device assumptions.

## Dart checks

From the package root, with each SDK selected on PATH:

```sh
flutter pub get
flutter test
flutter analyze
flutter pub publish --dry-run
(cd example && flutter pub get && flutter test && flutter analyze)
```

## CocoaPods: Flutter 3.38

Record the current SwiftPM setting before changing it; restore it after this
check. The example includes an iOS 15 Podfile and valid storyboard resources.

```sh
flutter config --no-enable-swift-package-manager
flutter precache --ios
(cd example && flutter pub get && flutter build ios --simulator --debug)
(cd example/ios && pod install)
xcodebuild -workspace example/ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator -destination 'id=SIMULATOR_UDID' \
  build CODE_SIGNING_ALLOWED=NO
ruby tool/native_tests.rb /absolute/path/to/flutter-3.38 SIMULATOR_UDID cocoapods
```

Replace the SDK path and `SIMULATOR_UDID`. The Ruby helper creates a fresh,
ignored `build/native-cocoapods-*` project, a scene-based application host, an
XCTest target referencing the checked-in fixtures, and a local Flutter engine
pod. `pod install` connects the actual plugin podspec. `xcodebuild test` runs
provider, geometry, transport, attachment, pause/resume, teardown, and timeout
fixtures and writes `CocoaPods.xcresult`. It does not require manually adding
sources or targets in Xcode. The podspec also declares a `ProviderTests` test spec.
The helper has been inspected on Windows but requires execution on Mac.

## SwiftPM: Flutter 3.44+

Use the other Flutter SDK; record its exact version. SwiftPM uses the current
[Flutter plugin-author guide](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors),
including the `FlutterFramework` dependency and `split-screen` library product.
Both package managers use `ios/split_screen/Sources/split_screen`.

```sh
flutter config --enable-swift-package-manager
flutter precache --ios
(cd example && flutter pub get && flutter build ios --simulator --debug)
xcodebuild -workspace example/ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator -destination 'id=SIMULATOR_UDID' \
  build CODE_SIGNING_ALLOWED=NO
ruby tool/native_tests.rb /absolute/path/to/flutter-3.44-or-later SIMULATOR_UDID swiftpm
```

Flutter's build command performs the example's SwiftPM migration. Review that
migration locally; ensure the plugin is resolved as a package, rather than
silently using CocoaPods. The fixture helper stages an exact copy of the plugin
and supplies the SDK's Flutter XCFramework as a local binary package. Its wired
`split_screenTests` target runs through the `split-screen` scheme and writes
`SwiftPM.xcresult`. If Xcode changes automatic scheme naming, inspect
`xcodebuild -list` inside the printed staging path and record the actual scheme.
Neither host generation nor fixture success proves system Duo behavior.

Restore the original SwiftPM configuration after checking both integrations.

## Runtime checks (both packaging paths)

Run `cd example && flutter run -d SIMULATOR_UDID`, or launch Runner from Xcode.

- [ ] Start attached with no hinge movement. Capability waits for the initial
  callback and returns the reported result; angle readings need no movement to
  initialize. Record whether the simulator supplies that initial sample.
- [ ] Start with the Flutter view temporarily unavailable. A capability request
  returns false within two seconds; a later request retries when attached.
- [ ] Use the simulator's supported fold/hinge controls. Record the controls and
  limitations present in this runtime, without assuming menu names or measurements.
- [ ] Transition flat/folded/closed where the simulator supports it. Active
  divisions alone produce folds; inactive flat regions do not force two panes.
  Angle reporting continues independently, including supplied flat/closed samples.
- [ ] Inspect full region frames and interactive margins. Confirm camera/occlusion
  regions never become folds. Do not inset the reported division frames.
- [ ] Rotate and resize in portrait/landscape. Check logical viewport coordinates,
  zero-area seams, removal of stale folds, and arrival of matching new geometry.
- [ ] Verify a late division update after the provisional empty snapshot and
  after a hinge callback is picked up by the next layout pass without another
  hinge movement. Keep entered form data and Router state through these updates.
- [ ] Profile an attached idle view and an angle-only subscription. There should
  be no continuous frame timer, no attachment retries once ready, and no region
  queries for angle-only listeners. Verify temporary detachment still retries and
  resume receives layout updates; inspect background and teardown cancellation.
- [ ] Verify the 600-logical-pixel example breakpoint with resizable windows,
  plus active-fold overrides, RTL ordering, and padding behavior.
- [ ] Background/resume and detach/reattach the Flutter hierarchy while both
  streams are subscribed. Geometry clears, interactions pause, and readings/layout
  resume without replacing supported Dart subscriptions.
- [ ] Cancel one channel while the other remains subscribed. Last cancellation,
  engine teardown, and pending capability requests remove all native resources.
- [ ] On an ordinary iPhone, verify false capability and no plugin folds/readings.
- [ ] On an older supported iOS runtime, verify runtime availability checks avoid
  Duo APIs, capability is false, and streams finish empty.
- [ ] Test engine-provided fold/hinge precedence if the Flutter engine supplies
  those features on this simulator/runtime.

## Evidence to record

| Check | Toolchain/runtime | Result / evidence |
| --- | --- | --- |
| CocoaPods example build | Flutter 3.38 + Xcode 27.1 | Pending Mac |
| CocoaPods provider/transport XCTest | Same + Simulator UDID/runtime | Pending Mac |
| SwiftPM example build | Flutter 3.44+ + Xcode 27.1 | Pending Mac |
| SwiftPM provider/transport XCTest | Same + Simulator UDID/runtime | Pending Mac |
| Initial callback and folding controls | Duo Simulator runtime | Pending Mac |
| Rotation, resize, background, teardown | Both packaging paths | Pending Mac |
| Idle scheduling and late region invalidation | Both packaging paths | Pending Mac |
| Ordinary iPhone fallback | Device/simulator runtime | Pending Mac |
| Older iOS fallback | Available supported runtime | Pending Mac |
| Sensor precision/physical accuracy | Physical Duo hardware | Deferred to hardware |

Document missing simulator controls, unsupported poses, callback differences,
and unavailable old runtimes. Do not infer physical sensor accuracy or update
rates from simulator fixtures, nor publish invented readings to make a test pass.
