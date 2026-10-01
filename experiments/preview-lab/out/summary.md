## 環境
$ xcodebuild -version
Xcode 27.0
Build version 27A266a
exit=0
$ sw_vers -productVersion
26.6.2
exit=0
$ bash -c xcrun simctl list runtimes
== Runtimes ==
iOS 26.2 (26.2 - 23C54) - com.apple.CoreSimulator.SimRuntime.iOS-26-2
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
iOS 27.0 (27.0 - 24A434) - com.apple.CoreSimulator.SimRuntime.iOS-27-0
watchOS 26.2 (26.2 - 23S303) - com.apple.CoreSimulator.SimRuntime.watchOS-26-2
exit=0
$ bash -c xcrun simctl privacy 2>&1 | head -60
Grant, revoke, or reset privacy and permissions
Usage: simctl privacy <device> <action> <service> [<bundle identifier>]

	action
	     The action to take:
	         grant - Grant access without prompting. Requires bundle identifier.
	         revoke - Revoke access, denying all use of the service. Requires bundle identifier.
	         reset - Reset access, prompting on next use. Bundle identifier optional.
	     Some permission changes will terminate the application if running.
	service
	     The service:
	         all - Apply the action to all services.
	         calendar - Allow access to calendar.
	         contacts-limited - Allow access to basic contact info.
	         contacts - Allow access to full contact details.
	         location - Allow access to location services when app is in use.
	         location-always - Allow access to location services at all times.
	         photos-add - Allow adding photos to the photo library.
	         photos - Allow full access to the photo library.
	         media-library - Allow access to the media library.
	         microphone - Allow access to audio input.
	         motion - Allow access to motion and fitness data.
	         reminders - Allow access to reminders.
	         siri - Allow use of the app with Siri.
	bundle identifier
	     The bundle identifier of the target application.

Examples:
	reset all permissions: privacy <device> reset all
	grant test host photo permissions: privacy <device> grant photos com.example.app.test-host

Warning:
Normally applications must have valid Info.plist usage description keys and follow the API guidelines to request access to services. Using this command to bypass those requirements can mask bugs.


exit=0
## シミュレータを用意する
A=iPhone 17 iOS 27.0 B=iPhone 17 Pro Max iOS 27.0 C=iPhone 17 iOS 26.5
## ビルド（#Preview(arguments:) を iOS 26 向け・Swift 6 でコンパイルできるか）
$ xcodegen generate
⚙️  Generating plists...
⚙️  Generating project...
⚙️  Writing project...
Created project at /Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/PreviewLab.xcodeproj
exit=0
$ xcodebuild build-for-testing -project PreviewLab.xcodeproj -scheme PreviewLab -destination generic/platform=iOS Simulator -derivedDataPath /Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/dd -quiet
error: the following command failed with exit code 0 but produced no further output
SwiftCompile normal arm64 /Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Sources/HealthProbe.swift (in target 'PreviewLab' from project 'PreviewLab')
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Sources/HealthProbe.swift:10:43: warning: 'appendInterpolation' is deprecated: Localized string interpolation produces an unlocalized, debug description for this type of value. Use a type supported by LocalizedStringKey.StringInterpolation or initialize a LocalizedStringResource instead with an interpolated value that conforms to CustomLocalizedStringResourceConvertible. [#DeprecatedDeclaration]
 8 |     var body: some View {
 9 |         VStack(spacing: 12) {
10 |             Text("isHealthDataAvailable: \(HKHealthStore.isHealthDataAvailable())")
   |                                           `- warning: 'appendInterpolation' is deprecated: Localized string interpolation produces an unlocalized, debug description for this type of value. Use a type supported by LocalizedStringKey.StringInterpolation or initialize a LocalizedStringResource instead with an interpolated value that conforms to CustomLocalizedStringResourceConvertible. [#DeprecatedDeclaration]
11 |             Button("Request authorization") {
12 |                 Task { await request() }

[#DeprecatedDeclaration]: <https://docs.swift.org/compiler/documentation/diagnostics/deprecated-declaration>
error: the following command failed with exit code 0 but produced no further output
SwiftCompile normal x86_64 /Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Sources/HealthProbe.swift (in target 'PreviewLab' from project 'PreviewLab')
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Sources/HealthProbe.swift:10:43: warning: 'appendInterpolation' is deprecated: Localized string interpolation produces an unlocalized, debug description for this type of value. Use a type supported by LocalizedStringKey.StringInterpolation or initialize a LocalizedStringResource instead with an interpolated value that conforms to CustomLocalizedStringResourceConvertible. [#DeprecatedDeclaration]
 8 |     var body: some View {
 9 |         VStack(spacing: 12) {
10 |             Text("isHealthDataAvailable: \(HKHealthStore.isHealthDataAvailable())")
   |                                           `- warning: 'appendInterpolation' is deprecated: Localized string interpolation produces an unlocalized, debug description for this type of value. Use a type supported by LocalizedStringKey.StringInterpolation or initialize a LocalizedStringResource instead with an interpolated value that conforms to CustomLocalizedStringResourceConvertible. [#DeprecatedDeclaration]
11 |             Button("Request authorization") {
12 |                 Task { await request() }

[#DeprecatedDeclaration]: <https://docs.swift.org/compiler/documentation/diagnostics/deprecated-declaration>
exit=0
## swift-snapshot-testing: A で撮る → A・B・C で比べる
### A で撮る
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Record mode is on. Automatically recorded snapshot: …
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Record mode is on. Automatically recorded snapshot: …
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Record mode is on. Automatically recorded snapshot: …
open "file:///Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/__Snapshots__/SnapshotStabilityTests/testSyncBanners.failed.png"
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Record mode is on. Automatically recorded snapshot: …
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:20: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Record mode is on. Automatically recorded snapshot: …
Test Case '-[PreviewLabTests.SnapshotStabilityTests testSyncBanners]' failed (0.000 seconds).
Test Suite 'SnapshotStabilityTests' failed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' failed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' failed at 2024-08-13 16:00:00.000.
** TEST EXECUTE FAILED **
### A で比べる（1 回目）
Test Case '-[PreviewLabTests.SnapshotStabilityTests testSyncBanners]' passed (0.000 seconds).
Test Suite 'SnapshotStabilityTests' passed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' passed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' passed at 2024-08-13 16:00:00.000.
** TEST EXECUTE SUCCEEDED **
### A で比べる（2 回目）
Test Case '-[PreviewLabTests.SnapshotStabilityTests testSyncBanners]' passed (0.000 seconds).
Test Suite 'SnapshotStabilityTests' passed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' passed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' passed at 2024-08-13 16:00:00.000.
** TEST EXECUTE SUCCEEDED **
### B（別の機種）で比べる
Test Case '-[PreviewLabTests.SnapshotStabilityTests testSyncBanners]' passed (0.000 seconds).
Test Suite 'SnapshotStabilityTests' passed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' passed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' passed at 2024-08-13 16:00:00.000.
** TEST EXECUTE SUCCEEDED **
### C（iOS 26）で比べる
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Snapshot "synced" does not match reference.
Newly-taken snapshot does not match reference.
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Snapshot "pending" does not match reference.
Newly-taken snapshot does not match reference.
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Snapshot "failed" does not match reference.
"file:///Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/__Snapshots__/SnapshotStabilityTests/testSyncBanners.failed.png"
"file:///Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/out/artifacts-c/SnapshotStabilityTests/testSyncBanners.failed.png"
Newly-taken snapshot does not match reference.
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:14: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Snapshot "offline" does not match reference.
Newly-taken snapshot does not match reference.
/Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/Tests/SnapshotStabilityTests.swift:20: error: -[PreviewLabTests.SnapshotStabilityTests testSyncBanners] : failed - Snapshot "list-device" does not match reference.
Newly-taken snapshot does not match reference.
Test Case '-[PreviewLabTests.SnapshotStabilityTests testSyncBanners]' failed (0.000 seconds).
Test Suite 'SnapshotStabilityTests' failed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' failed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' failed at 2024-08-13 16:00:00.000.
** TEST EXECUTE FAILED **
## ImageRenderer で List を描けるか
IOSurfaceClientSetSurfaceNotify failed e00002c7
2026-10-01 09:34:31.393714+0900 PreviewLab[72927:48455422] fopen failed for data file: errno = 2 (No such file or directory)
2026-10-01 09:34:31.678850+0900 PreviewLab[72927:48455422] fopen failed for data file: errno = 2 (No such file or directory)
Test Case '-[PreviewLabTests.ImageRendererTests testRender]' passed (0.000 seconds).
Test Suite 'ImageRendererTests' passed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' passed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' passed at 2024-08-13 16:00:00.000.
** TEST EXECUTE SUCCEEDED **
## SnapshotPreviews: どのプレビューを見つけ、trait を当てるか
Test Case '-[PreviewLabTests.LabPreviewSnapshots portrait-Health Probe-0-0]' passed (0.000 seconds).
Test Case '-[PreviewLabTests.LabPreviewSnapshots portrait-Views-0-1]' passed (0.000 seconds).
Test Case '-[PreviewLabTests.LabPreviewSnapshots portrait-Views-0-2]' passed (0.000 seconds).
Test Case '-[PreviewLabTests.LabPreviewSnapshots portrait-Views-0-3]' passed (0.000 seconds).
Test Case '-[PreviewLabTests.LabPreviewSnapshots portrait-Views-0-4]' passed (0.000 seconds).
Test Suite 'LabPreviewSnapshots' passed at 2024-08-13 16:00:00.000.
Test Suite 'PreviewLabTests.xctest' passed at 2024-08-13 16:00:00.000.
Test Suite 'Selected tests' passed at 2024-08-13 16:00:00.000.
** TEST EXECUTE SUCCEEDED **
PreviewLab_HealthProbe.swift_health.json
PreviewLab_HealthProbe.swift_health.png
PreviewLab_Views.swift_arguments.json
PreviewLab_Views.swift_arguments.png
PreviewLab_Views.swift_list.json
PreviewLab_Views.swift_list.png
PreviewLab_Views.swift_modifier.json
PreviewLab_Views.swift_modifier.png
PreviewLab_Views.swift_plain.json
PreviewLab_Views.swift_plain.png
## simctl privacy でヘルスケアの権限を与えられるか
$ xcrun simctl install C4127917-EE97-4500-B5BD-0EEA6755DA8A /Users/gntk/repository/nu-tori-preview-lab/experiments/preview-lab/dd/Build/Products/Debug-iphonesimulator/PreviewLab.app
exit=0
$ xcrun simctl privacy C4127917-EE97-4500-B5BD-0EEA6755DA8A grant health dev.nutori.lab.PreviewLab
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=1):
Simulator device failed to complete the requested operation.
Operation not permitted
Underlying error (domain=NSPOSIXErrorDomain, code=1):
	Failed to create TCC authorization record
	Operation not permitted
exit=1
$ xcrun simctl privacy C4127917-EE97-4500-B5BD-0EEA6755DA8A grant healthkit dev.nutori.lab.PreviewLab
An error was encountered processing the command (domain=NSPOSIXErrorDomain, code=1):
Simulator device failed to complete the requested operation.
Operation not permitted
Underlying error (domain=NSPOSIXErrorDomain, code=1):
	Failed to create TCC authorization record
	Operation not permitted
exit=1
## おわり
out/summary.md と画像ができた。次に CHECKLIST.md の手で確かめる項目をやり、結果を out/manual.md に書いてから:
  git add -f experiments/preview-lab/out && git commit -m 'プレビューの試しの結果を置く' && git push
