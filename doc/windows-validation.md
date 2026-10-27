# Windows validation record

Validated on October 17, 2026, on branch `duo`, created from the verified clean
commit `5477c7e8cca4f6130de7b0bb224f2f27d2f0337f`.

Toolchain: Flutter 3.47.4 stable, Dart 3.13.3, Windows x64. This does not substitute
for the Flutter 3.38 CocoaPods / 3.44+ SwiftPM matrix in
[iOS validation](ios-validation.md).

| Check | Result |
| --- | --- |
| Package `flutter test` | 65 passed; the browser-only test is skipped on the VM |
| Example `flutter test` | 4 passed |
| Package and example `flutter analyze` | No issues |
| Chrome web passthrough test, iOS target override | 1 passed with the test-environment workaround below |
| `flutter pub publish --dry-run` | Archive validated; exit 65 with one warning for uncommitted changes |
| `git diff --check` | Passed |
| Android implementation and tag-triggered workflow | No diff from the base commit |
| Swift, CocoaPods, SwiftPM, XCTest, simulator/device runtime | Not executable on Windows; pending Mac |

The dry-run did not upload or publish anything. It initially also reported the
plural `docs` directory; that was corrected to `doc`. The remaining warning is
expected for this uncommitted implementation. No release tag was created.

The installed Flutter 3.47.4 Windows browser test server returned 404 for its
`/canvaskit/chromium/canvaskit.js` and `.wasm` URLs even though those assets existed
in the SDK cache. A fresh web precache did not resolve that test-server issue.
For this run only, Chrome DevTools Fetch interception supplied the two exact
installed assets to the isolated headless test browser; the waiting test iframe
was reloaded. The normal Flutter test runner then executed the unchanged test
and exited successfully. No production source or installed SDK source was patched.
A plain browser-test command on this machine still needs that environment issue
resolved; repeat the browser check on another toolchain/host as appropriate.

Command logs are in ignored local `build/package-tests.log`,
`build/web-test.log`, and `build/publish-dry-run.log`. Native fixtures and their
host generator are checked in; their compilation and execution are unverified.
The [Mac checklist](ios-validation.md) includes exact build/test commands and a
place to record simulator controls, unavailable poses/runtimes, and physical
sensor accuracy deferred to hardware.

## Combined review follow-up

The Flutter subreview and Antigravity review were combined as follows:

* Two new regressions reproduced ordinary child state loss and replacement of
  `MaterialApp.router`'s Router on the first snapshot. Keeping the iOS wrapper's
  MediaQuery element stable fixes both, including resize and engine precedence.
* Removed the native continuous display link. Geometry refreshes from view
  layout/safe-area, hinge, and scene callbacks, with a requested layout pass after
  hinge updates. Attachment retries stop once the hierarchy is usable, and
  angle-only subscribers do not query regions. Added native fixtures for these
  behaviors; they remain uncompiled and unexecuted until Mac validation.
* Kept the explicitly agreed Xcode 27.1 + Duo SDK build requirement. A Swift
  compiler-version check alone cannot establish whether the SDK has Duo APIs.
* Kept wrapper placement documented instead of warning whenever a hinge exists
  without a fold: an inactive division on a flat device is valid behavior.

The two Flutter regressions failed before the fix; all ten wrapper tests pass
after it. The web test result above is from the earlier run; its unchanged
passthrough branch and the documented Windows server workaround still apply.
