# iOS validation checklist and Mac record

Native compilation and runtime behavior are **unverified**. The October 27 Mac
run below reaches compilation through both package managers, but the installed
SDK does not declare `UIHingeInteraction`. A passing Dart suite is not evidence
of Duo hardware support. Complete this checklist with a Duo-capable SDK before
claiming native acceptance; keep command output and `.xcresult` files.
Do not create a release tag or publish the package during validation.

## Prerequisites and matrix

* Xcode with an SDK declaring the Duo APIs used by the source, and an iOS 27.1+
  Duo Simulator runtime for system behavior checks. Run `xcodebuild -version`,
  `xcodebuild -showsdks`, and `xcrun simctl list devices available`. An Xcode
  version number alone does not establish whether those APIs are present.
* Use the installed Flutter SDK for both package managers and record its exact
  `flutter --version` output. Per the Mac follow-up, no separate Flutter SDK
  download or historical-version matrix is required. This run uses 3.47.2 for
  both paths. Older declared Flutter versions are not independently verified.
* CocoaPods and its Ruby `xcodeproj` dependency (`gem install cocoapods` if needed).
* An ordinary iPhone simulator/device and an older supported iOS runtime for
  availability/fallback checks. Use the oldest runtime available to the selected Xcode;
  if iOS 15 cannot run there, record that coverage gap explicitly.

Use an SDK path and a simulator UDID returned by `simctl` in the commands below.
The fixture dimensions are arbitrary test inputs, never device assumptions.

## Dart checks

From the package root, with the installed SDK selected on PATH:

```sh
flutter pub get
flutter test
flutter analyze
flutter pub publish --dry-run
(cd example && flutter pub get && flutter test && flutter analyze)
```

## CocoaPods

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
ruby tool/native_tests.rb /absolute/path/to/flutter SIMULATOR_UDID cocoapods
```

Replace the SDK path and `SIMULATOR_UDID`. The Ruby helper creates a fresh,
ignored `build/native-cocoapods-*` project, a scene-based application host, an
XCTest target referencing the checked-in fixtures, and a local Flutter engine
pod. `pod install` connects the actual plugin podspec. `xcodebuild test` runs
provider, geometry, transport, attachment, pause/resume, teardown, and timeout
fixtures and writes `CocoaPods.xcresult`. It does not require manually adding
sources or targets in Xcode. The podspec also declares a `ProviderTests` test spec.
The helper has now been executed on Mac; its results are recorded below.

## SwiftPM

Use the same installed Flutter SDK; record its exact version. SwiftPM uses the
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
ruby tool/native_tests.rb /absolute/path/to/flutter SIMULATOR_UDID swiftpm
```

Flutter's build command performs the example's SwiftPM migration. Review that
migration locally; ensure the plugin is resolved as a package, rather than
silently using CocoaPods. The fixture helper stages an exact copy of the plugin
and supplies the SDK's Flutter XCFramework as a local binary package. Its wired
`split_screenTests` target runs through the `split_screen` scheme and writes
`SwiftPM.xcresult`. The library product is named `split-screen`; Xcode's test
scheme is named after the package. If Xcode changes automatic scheme naming, inspect
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
| CocoaPods example build | Flutter 3.47.2 + Xcode 26.6 / iOS SDK 26.5 | Reaches Swift; blocked by missing `UIHingeInteraction` |
| CocoaPods provider/transport XCTest | Same + iPhone 17 Pro / iOS 26.5 | Build blocked; no fixtures executed |
| SwiftPM example build | Same, isolated source copy named `split_screen` | Package resolved; same SDK compilation blocker |
| SwiftPM provider/transport XCTest | Same + iPhone 17 Pro / iOS 26.5 | Scheme corrected; same SDK blocker; no fixtures executed |
| Initial callback and folding controls | No Duo runtime installed | Unavailable |
| Rotation, resize, background, teardown | Both packaging paths | Native checks blocked at compilation |
| Idle scheduling and late region invalidation | Both packaging paths | Native checks blocked at compilation |
| Ordinary iPhone fallback | iPhone simulators available | Cannot launch this plugin until compiled with a Duo SDK |
| Older iOS fallback | iOS 18.1 available; iOS 15 unavailable | Cannot launch this plugin until compiled with a Duo SDK |
| Sensor precision/physical accuracy | Physical Duo hardware | Deferred to hardware |

Document missing simulator controls, unsupported poses, callback differences,
and unavailable old runtimes. Do not infer physical sensor accuracy or update
rates from simulator fixtures, nor publish invented readings to make a test pass.

## Mac validation — October 27, 2026

The checkout was clean on `main`, then fetched, switched to `duo`, and
fast-forward checked. Handoff commit
`379dfbe45f0bb9ad6161198ffffd0bbc5f4d5e90` is an ancestor of this work. Only the
installed Flutter SDK was used; no additional Flutter SDK was downloaded.

### Installed toolchain and destinations

| Component | Actual value |
| --- | --- |
| Host | macOS 26.5.2, build `25F84`, Apple Silicon |
| Flutter | 3.47.2 stable, framework `d3b14c8769`, engine revision `a804b26164` |
| Flutter SDK path | `/Volumes/EXTERNAL/flutter` (`/Users/mark/flutter` is a symlink to it) |
| Dart / DevTools | 3.13.2 / 2.60.0 |
| Selected Xcode | 26.6, build `17F113`, `/Applications/Xcode.app/Contents/Developer` |
| Swift | 6.3.3 (`swiftlang-6.3.3.1.3`, clang `2100.1.1.101`) |
| iOS / iOS Simulator SDK | 26.5; no Duo SDK installed |
| CocoaPods / xcodeproj | 1.16.2 / 1.27.0, using `/usr/local/bin/pod` and system Ruby |
| Ruby | 2.6.10p210, universal arm64 |
| Selected simulator | iPhone 17 Pro, iOS 26.5 (`23F77`), UDID `42080BC5-E367-4729-B223-00ADFB3683FE` |
| Other installed runtimes | iOS 18.1 (`22B81`) and iOS 26.4.1 (`23E254a`); no iOS 15 or iOS 27.1+ |
| Deployment target | Source manifests and example retain iOS 15.0; runtime gates retain iOS 27.1 |

### Results

| Check | Result | Log under `build/mac-validation/` |
| --- | --- | --- |
| Package `flutter pub get` | Passed | `flutter-3.47-pub-get.log` |
| Package `flutter test` | 65 passed; one browser-only test skipped in VM | `flutter-3.47-package-tests.log` |
| Package `flutter analyze` | No issues | `flutter-3.47-package-analysis.log` |
| Example `pub get`, `test`, `analyze` | Passed; 4 tests; no analysis issues | `flutter-3.47-example-{pub-get,tests,analysis}.log` |
| Web passthrough with iOS target override | 1 passed in headless Microsoft Edge; no interception/workaround needed | `web-tests.log` |
| Package archive dry run | Clean committed tree: exit 0, zero warnings; initial run warned about uncommitted edits | `publish-dry-run-clean.log`, `publish-dry-run.log` |
| CocoaPods example Flutter build | `pod install` succeeded, including `split_screen`; Swift compile blocked by missing SDK type | `cocoapods-example-build.log` |
| CocoaPods example direct Xcode build | Same compilation blocker, exit 65 | `cocoapods-xcodebuild.log` |
| CocoaPods native XCTest command | Pods installed; build failed before any tests executed | `cocoapods-native-tests.log` |
| SwiftPM example in original checkout | Flutter migration hit package identity mismatch | `swiftpm-example-build.log` |
| SwiftPM example in isolated copy | Migration and package resolution succeeded; Swift compile blocked by missing SDK type | `swiftpm-staged-example-build.log`, `swiftpm-xcodebuild.log` |
| SwiftPM native XCTest command, handoff runner | Failed: no scheme named `split-screen` | `swiftpm-native-tests.log`, `swiftpm-schemes.json` |
| SwiftPM native XCTest command, corrected runner | Scheme `split_screen` resolved; build failed before tests at missing SDK type | `swiftpm-native-tests-fixed.log` |
| Ruby runner regression | 1 test, 8 assertions, passed; models Xcode invocation only | `native-runner-regression.log` |

Both packaging paths report the same concrete compiler error:

```text
Providers.swift:33:30: error: cannot find type 'UIHingeInteraction' in scope
    private var interaction: UIHingeInteraction?
```

This is a missing SDK declaration, so an `@available` runtime check cannot make
it compile. No API substitutes, compiler-version gates, invented readings, or
changes to the deployment/runtime targets were added to bypass it. Compilation
with an actual Duo SDK is still needed to establish whether the adapters use
the correct API signatures and to expose any later compile/test failures.

### Packaging findings and reproduction

`xcodebuild -list -json` on the staged native package reports only
`split_screen`. The runner now uses that package scheme, rather than the
`split-screen` library product. Run its invocation regression with
`ruby tool/native_tests_test.rb`. This regression uses a fake `xcodebuild` and
does not claim native fixture coverage. Actual Xcode execution after the fix
resolved the package and reached the real Swift compiler.

Flutter 3.47.2's example migration also encountered the reported upstream
[checkout-name identity issue](https://github.com/flutter/flutter/issues/186881):
the generated dependency uses `flutter-splitscreen`, while the example's direct
package reference uses `split_screen`. For this run an isolated source copy was
created at `build/mac-validation/split_screen`, excluding `.git`, SDK/build
outputs, Dart caches, Pods, symlinks, and generated Flutter packages. Its example
was built with the same installed Flutter SDK. No source/API patches were applied
to that copy. The resulting generated package resolves `../.packages/split_screen`
and links the `split-screen` product. Its Podfile.lock contains **only Flutter**;
the plugin is compiled from the `split_screen` Swift package, not a fallback pod.
Flutter warned that the custom Podfile still retains CocoaPods engine integration.
This is therefore verified SwiftPM plugin resolution with residual engine pod
integration, not a successful fully migrated application build.

Flutter settings were isolated with
`XDG_CONFIG_HOME="$PWD/build/mac-validation/flutter-config"` before running
`flutter config --no-enable-swift-package-manager` and then
`flutter config --enable-swift-package-manager`. The user's original setting was
`(Not set)` and was not changed. Cached iOS engine frameworks were already
present; no `precache` or SDK installation was needed. Automatic example project
upgrades were retained in the isolated copy for inspection; incidental upgrades
in the original checkout were restored before committing.

Native fixture commands used these actual arguments:

```sh
ruby tool/native_tests.rb /Volumes/EXTERNAL/flutter 42080BC5-E367-4729-B223-00ADFB3683FE cocoapods
ruby tool/native_tests.rb /Volumes/EXTERNAL/flutter 42080BC5-E367-4729-B223-00ADFB3683FE swiftpm
```

All paths below are relative to this repository. Logs and binary result bundles
remain local in ignored `build/`; they are not shipped in the package or Git.

| Evidence | Actual `.xcresult` path |
| --- | --- |
| CocoaPods example build | `build/mac-validation/CocoaPodsExample.xcresult` |
| CocoaPods fixture build failure | `build/native-cocoapods-20261027-64166-1w8ggzy/CocoaPods.xcresult` |
| SwiftPM example build | `build/mac-validation/SwiftPMExample.xcresult` |
| SwiftPM fixture scheme failure before fix | `build/native-swiftpm-20261027-65074-lhs9ak/SwiftPM.xcresult` |
| SwiftPM fixture compile failure after fix | `build/native-swiftpm-20261027-66104-v2efvn/SwiftPM.xcresult` |

Toolchain inventory is in the `*-version.log`, `xcode-sdks.log`, `simulators.log`,
and `runtimes.log` files under `build/mac-validation/`. The original Flutter
setting is in `flutter-config-before.log`; `flutter-config-after.log` matches it.

### Remaining runtime coverage

No native fixtures or example runtime checks executed: neither integration could
compile with the installed SDK. Initial attachment without hinge movement,
system folding controls, late region invalidation, active region filtering and
margins, rotation/resizing, background/resume, detachment, cancellation, teardown,
idle scheduling, and angle-only region-query behavior remain unverified natively.
The Dart tests do verify child/Router state preservation through mocked geometry
changes, engine feature precedence, stream lifetimes/cancellation, replay, and
supplied flat/closed readings; that does not establish UIKit callback behavior.

Ordinary iPhone and older-runtime fallback remain untested despite available
iPhone simulators and iOS 18.1. A Duo-capable SDK is required to build the binary
before it can run on those older destinations. iOS 15 is not installed. No Duo
simulator exists in the installed runtimes, so folding controls and supported
poses could not be inspected. Sensor accuracy and physical readings remain
hardware-only coverage. No package was published and no release tag was created.
