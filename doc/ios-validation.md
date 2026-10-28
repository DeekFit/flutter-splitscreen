# iOS validation checklist and Mac record

Native fixtures pass through both package managers with the upgraded Xcode 27.1
Duo SDK. The example also runs on the iOS 27.1 Duo simulator; see the
[October 28 record](#mac-validation--october-28-2026). The October 27 SDK blocker
below is historical. Fixture and simulator success do not establish physical
sensor accuracy; keep command output and `.xcresult` files.
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

## October 27 evidence (superseded by the October 28 run below)

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

## Mac validation — October 28, 2026

Revalidated after the host/Xcode upgrade, using the same installed Flutter SDK.
The SDK now declares `UIHingeInteraction` and UIView reserved regions, and the
unchanged production adapters compile. No additional Flutter SDK was installed.

| Component | Actual value |
| --- | --- |
| Host | macOS 27.2 (`26B123`), Apple Silicon |
| Xcode | 27.1 (`27A9275`) |
| Swift | 6.4 (`swiftlang-6.4.0.34.1`, clang `2100.3.34.1`) |
| iOS Simulator SDK | 27.1 (`24A94232`) |
| Flutter / Dart | 3.47.2 stable (`d3b14c8769`) / 3.13.2 |
| Flutter SDK | `/Volumes/EXTERNAL/flutter` |
| Duo simulator | iOS 27.1 (`24A94425`), UDID `57E5A434-D3F4-420E-AA1C-2281959040E4` |
| Deployment / runtime gates | iOS 15.0 / iOS 27.1, unchanged |

Both commands below completed successfully, each executing all eight fixtures
with zero failures:

```sh
ruby tool/native_tests.rb /Volumes/EXTERNAL/flutter 57E5A434-D3F4-420E-AA1C-2281959040E4 cocoapods
ruby tool/native_tests.rb /Volumes/EXTERNAL/flutter 57E5A434-D3F4-420E-AA1C-2281959040E4 swiftpm
```

The first CocoaPods attempt found a **fixture** exclusivity crash when assigning
`nil` to a captured view. UIView deallocation synchronously notified the anchor,
whose callback read the same variable before its mutation finished. Retaining
the previous view with `withExtendedLifetime` until after that assignment fixes
the fixture while preserving the real detachment callback. The original test
now passes in both integrations. Production observation code was not changed.

| Check | Result / evidence under `build/mac-validation-2026-10-28/` |
| --- | --- |
| Package tests | 65 passed; browser-only test skipped in VM; `package-tests.log` |
| Package analysis | No issues; `package-analysis.log` |
| Example Dart checks | 4 tests passed; analysis clean; `example-tests.log`, `example-analysis.log` |
| Runner invocation regression | 1 test, 8 assertions passed |
| CocoaPods example build | Passed; `cocoapods-example-build.log` |
| CocoaPods native fixtures | 8 passed; `cocoapods-native-tests.log` |
| SwiftPM native fixtures | 8 passed; `swiftpm-native-tests.log` |
| SwiftPM example build | Passed; `swiftpm-example-build.log`; same isolated-copy workaround as October 27 |

Result bundles remain in ignored local directories:

* `build/native-cocoapods-20261028-24939-1ccwwwp/CocoaPods.xcresult`
* `build/native-swiftpm-20261028-27791-1d8zoj/SwiftPM.xcresult`
* Initial crashing fixture: `build/native-cocoapods-20261028-19073-yjhr8/CocoaPods.xcresult`

### Actual Duo example behavior

Using Device Hub's **Open**, **Partially Open**, **Closed**, **Rotate Right**,
and **Home** controls, the CocoaPods example demonstrated:

* Initial attachment without moving the hinge: capability `true`, angle 180°.
* Partially open: live angle updates and panes on opposite sides of the actual
  active division. `example-partial.png` records the simulator output.
* Rotation while partially open: columns become top/bottom panes along the
  horizontal division, with no second hinge movement required.
* Closed: the supplied 0° reading is retained and the layout returns to its
  width-based policy when the division becomes inactive.
* Reopen: 180° is reported again. Backgrounding with Home, resuming, and folding
  again continues to deliver both geometry and angle updates.

The eight native fixtures separately verify bounded/retryable initialization,
late geometry after provisional empty output, a second layout pass, geometry
conversion/margins/zero-area seams, coalescing, cancellation, pause/resume, and
teardown. They verify no attachment retry once ready and no region queries for
angle-only demand. These scheduling checks use injected providers, rather than
claiming an Instruments profile or physical sensor measurements.

The cached Flutter framework carried 600/700 file modes into the generated
example bundle. Simulator installation initially reported its Info.plist as
missing. `chmod -R a+rX` on the **generated Runner.app only** corrected those
permissions; installation and launch then succeeded. No installed SDK files were
edited. Simulator screenshot services could not write directly to the external
volume, so captures were written to `/private/tmp` and copied into the ignored
evidence directory by the shell.

The SwiftPM-built example was subsequently launched with `flutter run` and
`--use-application-binary` from the isolated copy. It initialized on an already
partially open Duo without hinge movement (capability true, angle 127.78°),
split along the division, reported 180° when open and 0° when closed, and
updated its division after rotation. `example-swiftpm-partial.png` records that
integration. As before, the plugin resolves as SwiftPM while the custom example
Podfile retains the Flutter engine pod entry; no `split_screen` pod is present
in the staged example's Podfile.lock.

### Ordinary iPhone and older-runtime fallback

The same CocoaPods example binary, compiled with the Duo SDK and deployment
target 15.0, ran successfully on the existing iPhone 16 Pro / iOS 18.1 simulator,
UDID `74F15225-405A-4CAA-B488-EEDD9E4EEA4D`. It displayed false capability and
no angle reading. Live MediaQuery inspection showed no display features in the
402 × 874 viewport, and the example rendered one pane. Evidence:
`example-ios18-fallback.png` and `example-ios18-geometry.json` under the current
validation directory. The simulator was returned to its original shutdown state.

A non-Duo iPhone **on iOS 27.1** could not be created: `simctl create` rejected
the iPhone 18 Pro profile with `Incompatible device` (CoreSimulator error 403).
`runtimes.json` confirms this installed 27.1 runtime supports only the iPhone Duo
device type. Thus the actual 27.1 ordinary-iPhone/no-hinge provider path remains
unverified; the native injected-provider fixtures cover nil hinge readings.
iOS 15 runtime coverage and physical Duo sensor accuracy remain unavailable.

### StitchPal consumer validation

StitchPal was tested in `/Volumes/EXTERNAL/src/deekfit/stitchpal`, starting from
monorepo commit `9186dc05764e63e773eab8acb7af8307550ca8b2` on `main`. The app
was first launched unchanged using the installed Flutter SDK:

```sh
flutter run --no-pub -d 57E5A434-D3F4-420E-AA1C-2281959040E4 --debug
```

It showed a normal width-based tablet layout, including the existing fixed
400-point sidebar, and did not align its columns with the partially open Duo's
division. This checkout was using the vendored `deekfit_common` TwoPane rather
than a direct package dependency.

The authorized local integration adds `split_screen` with
`path: ../../flutter-splitscreen`, switches the three TwoPane imports, and places
`SplitScreen(child: child)` in `MaterialApp.builder`. The home layout now permits
division-driven pane proportions and supplies the body's full-view offset below
the app bar and above navigation/keyboard insets. Explicit full-screen pane
priority is retained. On native iOS, active folds can select both panes before
an angle/posture sample; Android and web retain their previous posture policy.
The native pod lock and plugin symlink resolve this exact local 2.0.0-dev.1.

After rebuilding and launching with the same command, live Flutter VM inspection
measured these actual coordinates (logical points):

| Pose | Native active division | Actual pane boundaries |
| --- | --- | --- |
| Partially open landscape, viewport 951 × 669 | x=455.5…495.5, y=0…669 | Sidebar ends at x=455.5; detail begins at x=495.5; both widths 455.5 |
| Rotated partially open portrait, viewport 669 × 951 | x=0…669, y=455.5…495.5 | Upper pane y=138…455.5; detail pane y=495.5…859 |

The full 40-point reported division is preserved. Opening flat returns to the
app's width policy. An unsaved `Duo layout draft` name in the detail form survived
folding, unfolding to the compact single-pane view, rotation, and backgrounding
with Home followed by resume. No pattern was saved and no account sign-in was
performed. Geometry and screenshots are in the ignored validation directory:

* `stitchpal-baseline-open.png`, `stitchpal-baseline-partial.png`
* `stitchpal-local-partial.png`, `stitchpal-local-rotated-draft.png`
* `stitchpal-local-partial-geometry.json`, `stitchpal-local-rotated-geometry.json`

The initial Flutter run's native build took 995.8 seconds; the run after adding
the native plugin took 1412.5 seconds. Both successfully launched. Earlier
generic/manual build attempts were cancelled; their logs/result bundle are
diagnostic artifacts and are not passing build evidence. Subsequent runtime
checks used `flutter run`, including the already built binary for fallback and
SwiftPM checks.

### StitchPal regression results and pre-existing failures

Three new app regressions cover late vertical/horizontal divisions, correct
Scaffold offsets, retained Navigator state, flat fallback, and an active iOS
division before angle initialization. Before the fix, the vertical case kept
the sidebar at 400 instead of 490, and the horizontal case ended the upper pane
at y=345.6 instead of 390. The focused layout/share/navigation suite now passes
all **38 tests** (`stitchpal-focused-tests.log`).

The complete app suite finished with **1,870 passed, 13 skipped, 14 failed**
(`stitchpal-all-tests.log`). All 14 failing cases were rerun in an isolated
`git archive` of the committed baseline source, with unchanged generated
localizations and dependency paths, and **all 14 also failed there**. They cover
PDF preview/cover rendering and existing text-scaling, chart-toolbar, and dialog
expectations. Their names are in `stitchpal-failures.json`; reproduction output
is in `stitchpal-baseline-failure-check.log` (first five) and
`stitchpal-baseline-other-failures.log` (remaining nine). These failures were not
changed as part of the Duo integration.

Full app analysis reports 345 existing issues (`stitchpal-analysis.log`). Analysis
of the five changed Dart files reports only three pre-existing informational
lints: two reports for an untyped method at `home_page.dart:255`, and a super
parameter suggestion in `stitch_pal_bootstrapper.dart`. It reports no errors or
warnings in those files (`stitchpal-changed-analysis.log`). Package and example
analysis are clean. StitchPal's local dependency and source changes remain in
the user's existing checkout for review; no app release or package publication
was performed.

## Automatic TwoPane integration — October 28 follow-up

The initial integration above required an application-level `SplitScreen`
wrapper. That requirement is superseded: `TwoPane` now observes native iOS
division geometry internally, with its existing constructor and override rules.
Applications using `TwoPane` need no root builder or platform checks. The example
has had its app wrapper removed. `SplitScreen` remains optional for custom
consumers of `MediaQuery.displayFeatures` outside `TwoPane`.

Nested layouts respect an ancestor's transformed/filtered MediaQuery rather
than reinserting the original full-view snapshot. Concurrent layouts share the
existing lazy receiver, replay and serialized cancellation. Engine features
still take precedence; Android and web start no native layout observation.
No Swift, Android, angle-channel, SDK/deployment gate, or release-workflow code
changed in this follow-up. The native XCTest result bundles above remain the
native evidence; those fixtures were not rerun for these Dart-only changes.

The new regression first failed against `f034e16` because an unwrapped TwoPane
ignored the native division. With automatic observation enabled but the old
single-pane branch retained, it failed again because the visible pane's nested
Navigator was recreated. Keeping each pane's MediaQuery ancestry stable fixes
that state loss for transitions between one and two panes.

Evidence is under `build/automatic-layout-validation/`:

| Check | Result / log |
| --- | --- |
| Package tests | 72 passed, browser-only test skipped in VM; `package-tests.log` |
| Package analysis | No issues; `package-analysis.log` |
| Example tests / analysis | 5 passed / no issues; `example-tests.log`, `example-analysis.log` |
| Web, installed Edge | 1 passed, including TwoPane with iOS target override and no native calls; `web-tests.log` |
| Native runner regression | 1 test, 8 assertions passed; `runner-tests.log` |
| Before-fix reproductions | `before-fix.log`, `before-state-fix.log` |

Seven new package regressions exercise wrapper-free late geometry, unknown
posture without an angle sample, full division margins, zero-area seams, stale
viewport rejection and rotation, flat removal, retained child/Navigator route
state, concurrent replay/cancellation, nested/filtered geometry, optional wrapper
compatibility, engine precedence, explicit overrides, Android passthrough, and
missing-plugin fallback. The additional example regression verifies its normal
application root needs no wrapper.

The CocoaPods example was rebuilt and launched with ordinary `flutter run`,
using the installed SDK and the existing isolated CocoaPods configuration.
On initial launch into an already partially open Duo, without hinge movement,
it reported capability true and 127.54 degrees. Live geometry inspection found
the native x=455.5…495.5 division and a 455.5-point-wide first pane in the
951 × 669 viewport. After rotation, the native division was y=455.5…495.5 and
the first pane ended at y=455.5 in the 669 × 951 viewport. Opening flat cleared
the feature and returned to 334.5-point columns. The supplied 180-degree and
0-degree readings were preserved. Logs, JSON and screenshots:

* `example-run-cocoapods.log`
* `example-partial-geometry.json`, `example-rotated-geometry.json`, `example-flat-geometry.json`
* `example-partial.png`, `example-rotated.png`

The first launch without the isolated CocoaPods configuration selected Flutter's
default SwiftPM migration and reproduced the already documented local-directory
identity error (`flutter-splitscreen` versus `split_screen`); see
`example-run.log`. It is diagnostic evidence, not a passing build.

The updated wrapper-free example also built successfully through SwiftPM using
the existing isolated directory named `split_screen` and the installed Flutter
SDK (`swiftpm-build.log`). Its retained Flutter engine pod is the same packaging
limitation described above; the plugin itself resolves through SwiftPM.
That binary was then launched on the already partially open Duo using normal
`flutter run --use-application-binary`, with no hinge movement. It reported true
capability and 127.78 degrees and split at y=455.5…495.5 in the 669 × 951 viewport.
Evidence: `swiftpm-run.log`, `swiftpm-partial-geometry.json`, and
`swiftpm-partial.png`.

The new CocoaPods binary was launched on the existing iPhone 16 Pro / iOS 18.1
simulator with `flutter run --use-application-binary`. It showed false sensor
capability, no angle reading, no display features, and one 402 × 874 pane.
Evidence: `example-fallback-run.log`, `example-fallback-geometry.json`, and
`example-fallback.png`. That simulator was returned to shutdown afterward.
The unavailable iOS 15 runtime, ordinary-iPhone iOS 27.1 profile, and physical
Duo/sensor-accuracy coverage remain unchanged.

StitchPal's earlier app-level `SplitScreen` wrapper and iOS-specific fold branch
have been removed. Its production integration now has no platform-specific Duo
layout code. Its custom `allowedOverrides` now allows the library to show both
panes on a division unless the current route explicitly requires full screen.
The existing generic proportion and Scaffold-offset corrections remain. The
focused layout/share suite passes 24 tests, including the same unknown-posture
division on Android and iOS, plus a native event reaching TwoPane without a root
wrapper (`stitchpal-focused-tests.log`).

The wrapper-free StitchPal build launched successfully using `flutter run`
(`stitchpal-run.log`). Before any hinge movement, portrait geometry was already
split: the upper pane ended at y=455.5 and the detail Navigator began at y=495.5.
After rotation, both pane widths were 455.5, with the detail beginning at x=495.5.
The existing 40-point reserved division was preserved in both orientations.
Opening flat in portrait returned to a single detail pane at (0, 138), size
669 × 721. An unsaved `Automatic Duo draft` name survived rotation, unfolding
to that single pane, folding again, Home/background, and resume. No pattern was
saved and no sign-in was performed. Evidence:

* `stitchpal-portrait-geometry.json`, `stitchpal-landscape-geometry.json`
* `stitchpal-flat-geometry.json`, `stitchpal-resumed-geometry.json`
* `stitchpal-landscape.png`, `stitchpal-resumed.png`

The complete app suite finished with **1,871 passed, 13 skipped, 15 failed**
(`stitchpal-all-tests.log`). Fourteen failures exactly match the baseline failures
already reproduced above (`stitchpal-failure-comparison.json`). The additional
failure was a 30-second timeout in the SQLite image-path test during overlapping
native builds. After the builds finished, all four tests in that file passed
with `--concurrency=1` (`stitchpal-sqlite-retry.log`). No database or unrelated
test code was changed. Full app analysis still reports 345 issues
(`stitchpal-analysis.log`); package/example analysis remain clean. The app
integration changes remain uncommitted in the user's existing DeekFit checkout.
