# Implementation Plan — UIKit Alert Presentation Migration

**Specification:** [Alert-controller specification](speckit.migration.alertcontrollers.specify.md)
**Task checklist:** [Alert-controller tasks](speckit.migration.alertcontrollers.tasks.md)
**Status:** Application implementation explicitly approved and completed for REQ-ALERT-1..9.
Scoped static gates passed; manual regressions are not run.

## Approved execution record — 2026-10-17

**Scope override:** The user approved application edits and stated “you should target only
the files in this task” and “that is also about the compile. you are cleared to proceed”.
This supersedes the whole-module preflight/typecheck and dependency-readiness requirements
in the original workflow and §3 recipe below; the recipe is retained as historical planning
context and was **not executed**. No delegation, dependency investigation/restoration,
whole-target compilation, Xcode build, or WebSocket checks were performed.

**Readiness:** The user's reported successful Carthage/Braintree build and app run is the
accepted T1 baseline, not an independently repeated build/run. Scoped Git inspection found
the nested `SwiftCinemas` project file already modified, and these three working docs
already modified/untracked. Exact task-file snapshots were retained under
`/var/folders/0m/dgl6bg054pv5yd27y3_l4bg00000gp/T/alerts-task-baseline-_4jj7qqs`
before edits; existing changes were preserved.

**Implementation:** One coherent app edit batch added the typed action and compatible
presenter, moved the original activation body unchanged into the confirmation handler,
migrated both Menu call sites without altering aggregation/dismissal, replaced Home's popup
(approved Close → OK), removed only the redundant Helpers extension, and replaced exactly
three venue dialogs without changing guards/messages/else paths. No contracts changed.
No test or dependency file was added or edited.

**Actual final checks:**

- Refreshed the SwiftCinemas MCP cache after the batch. Its build-verification actions are
  target-wide, not task-file compiler checks, so they were not invoked.
- `xcrun --sdk iphonesimulator --show-sdk-path` exited 0, selecting the installed
  `iPhoneSimulator27.0.sdk`. No dependency or DerivedData search was performed.
- `xcrun --sdk iphonesimulator swiftc -frontend -parse -swift-version 6 -sdk "$SDK"
  -target arm64-apple-ios17.6-simulator <six-task-Swift-files>` exited **0**.
  The files were HomeVC, MenuVC, Helpers, VenuesDetailsVC, Alerts/AlertAction, and
  Alerts/AlertPresenter under `SwiftCinemas/SwiftLoginScreen/`. This is **syntax only**.
- `xcrun --sdk iphonesimulator swiftc -typecheck -swift-version 6 -sdk "$SDK"
  -target arm64-apple-ios17.6-simulator
  SwiftCinemas/SwiftLoginScreen/Alerts/AlertAction.swift` exited **0**. An initial
  enum-only invocation without explicit SDK/target exited 1 (simulator sysroot/macOS
  target mismatch); the corrected invocation above passed with no source change.
  Only the standalone enum was typechecked, not the presenter/controllers or module.
- `plutil -convert json -o - <project.pbxproj>` plus Python baseline assertions verified
  app target `EA62FD4F1989F6AC00469896`, classic Sources phase
  `EA62FD4C1989F6AC00469896`, and parent group `EA62FD521989F6AC00469896`.
  New build refs `AC1700012026101700000001` / `...0002` resolve through file refs
  `...0003` / `...0004` and Alerts group `...0005` to the exact new on-disk paths,
  each once and app-only. All pre-existing PBX objects are unchanged except the approved
  group/Sources arrays; test membership, build settings and dependencies are unchanged.
- Python scoped source/baseline assertions passed: one default-compatible helper, two
  typed Menu paths, unchanged activation body within OK, three exact venue replacements,
  unchanged unrelated helpers, no legacy string helper/dispatch, popup, or `UIAlertView`
  in the six scoped Swift files. No whole-app inventory is claimed.
- Reviewed the complete seven-file application diff against the retained dirty baseline,
  not merely HEAD; only approved edits were present. Scoped
  `git -C SwiftCinemas diff --check -- <five-existing-app-files>` exited **0**.

**Limits / not run:** Presenter/controller and whole-module typechecks, builds and automated
runtime tests were not run; no dependency work was attempted to enable them. All manual
scenarios in the specification/T7 remain unchecked: direct/pending activation once and only
on confirmation, missing-user/error behavior, ordinary Menu/logout, Home empty basket, all
three venue guards, and representative existing alert flows. Static source comparison is
not runtime proof. No safe supported runtime harness was established within this scope.
No commit or push was performed.

## 1. Scope and design

Implement only the UIKit requirements in the specification:

- Add `SwiftCinemas/SwiftLoginScreen/Alerts/AlertAction.swift` and
  `SwiftCinemas/SwiftLoginScreen/Alerts/AlertPresenter.swift`.
- Move the `UIViewController` alert helpers out of `HomeVC.swift`; replace the
  string-dispatched activation helper with `AlertAction`.
- Update `MenuVC`'s direct and pending-alert activation paths.
- Replace `HomeVC`'s empty-basket `UIAlertController.popUp` use and remove the helper.
- Replace the three `UIAlertView` dialogs in `VenuesDetailsVC`.
- Add the two source files to the app target as confirmed by the preflight project-file
  inspection.

Do not implement `AlertItem`, SwiftUI alert binding, WebSocket publishing, seat-map updates,
toast/notification handling, or reconnect changes. Do not touch backend contracts,
`AppServices` wiring, `AppDelegate`, networking layers, checkout, URLs, headers, or payloads.
Existing action sheets, popovers, and bespoke alert flows remain outside this refactor.

### Behavior and architecture constraints

- Preserve `presentAlert(withTitle:message:)` source compatibility by making the new action
  parameter default to `.none`. The default path remains a UIKit `.alert` with its current
  title/message and **OK** default action.
- Use a typed action (`.none`, `.resendActivation`, `.custom`) instead of a function-name
  string. The activation action runs only after confirmation.
- Preserve the current `UserDefaults["USERNAME"]` lookup and call to
  `AuthDataManager.shared.activateCurrentDevice(user:)`. Use its existing async/await
  operation on the main actor; do not duplicate activation networking or bypass the
  existing injected data-manager/AppServices path.
- Preserve `MenuVC.presentMenuError`'s existing message combination and alert replacement
  flow. The current implementation does not justify the old plan's unconditional
  double-alert claim; do not add or assume that behavior.
- Preserve the three date-guard conditions and their current alert title/message.
- Replace the `HomeVC` popup with the shared presenter. The **Close** to **OK** button-label
  change is an explicit, accepted consistency change; preserve the empty-basket message.
- No new third-party package or dependency.

## 2. Implementation workflow

The eventual code change is one coherent edit batch, not an edit-and-validate loop. Do not
run application builds, parse/typecheck, tests, or repeated inventories between individual
edits. Use MCP-assisted targeted inspection/editing only within the approved paths. If an
unexpected mismatch appears, inspect that point narrowly; restart preflight only if it
materially changes the baseline or assumptions.

### Gate 0 — implementation authorization

This deliverable is documentation only. Stop here until the user separately approves
application implementation. Commit or push is never implied.

### Gate 1 — preflight before any app-source edit

Capture and retain a baseline for the planned paths before changing source:

1. Record the working-tree status and scoped diff. Preserve existing user-owned and
   unrelated changes; do not reset or stash them. Include only this feature's explicitly
   approved files in any implementation diff.
2. Inventory the relevant alert declarations, call sites, all activation-helper uses,
   `UIAlertView` uses, `popUp` declarations/callers, and their current messages and
   conditions. Avoid relying on old counts, line numbers, or copied inventories.
3. Resolve the real Xcode app target and its source-membership model from
   `SwiftCinemas.xcodeproj/project.pbxproj`. Record the target/configuration, resolved
   PBX object IDs and repo-relative paths for the affected files, and verify there are no
   missing or duplicate path/name resolutions. Confirm whether app membership is a classic
   Sources phase or a synchronized group; do not infer it from the test target. A two-file
   source-count increase alone is not proof of correct membership.
4. Capture the selected target's effective Swift version, SDK, deployment target, bridging
   header, module/framework search paths, and required dependency availability. Do not use
   a guessed source list or select an arbitrary/latest DerivedData directory.
5. Capture baseline `swiftc -typecheck` diagnostics for the exact app-target Swift source
   set with the real configuration, using the no-build recipe in §3. The recipe uses
   `xcodebuild -showBuildSettings` only to read settings; it does not invoke an Xcode build,
   resolve/update packages, or restore dependencies. Keep the compiler's exit status intact;
   distinguish pre-existing diagnostics from any later regression. Do not call a missing
   dependency a successful typecheck.
6. Record the intended file-level change list and the manual regression cases from the
   specification before editing.

If a required dependency or baseline diagnostic cannot be established, stop before edits.
Request approval for any baseline/dependency restoration needed to unblock the work; do not
silently build, replace, or modify project state.

### Gate 2 — coherent source-edit batch

1. **Add shared types and presenter; move the existing extension atomically.** Create
   `AlertAction.swift` and `AlertPresenter.swift`, remove the old extension from `HomeVC.swift`,
   and register both files in the app target using the resolved project structure from
   Gate 1. Pair removal and addition in the same batch to avoid duplicate declarations.
2. **Migrate activation.** Replace every `presentAlertWithFunction` use in `MenuVC` with the
   typed action. Preserve both the direct activation-required alert and the pending-alert
   dismissal/upgrade path, including combined error text and no-overlap behavior.
3. **Remove the duplicate popup helper.** Replace the one `HomeVC` empty-basket call with the
   shared helper, then remove `UIAlertController.popUp` from `Helpers.swift`.
4. **Migrate deprecated dialogs.** Replace the three `UIAlertView` blocks in
   `VenuesDetailsVC` using the exact messages and guard conditions captured in Gate 1.
5. Keep unrelated call sites source-compatible. Do not opportunistically reformat or
   refactor other alert flows.

### Gate 3 — consolidated final verification

Run once after the coherent batch is complete:

1. **Syntax:** parse every changed Swift file using the selected app target's Swift toolchain
   and SDK.
2. **Exact target membership:** resolve each new PBX build/file reference and group path to
   its on-disk file; verify the two new files are members of the app target, and that no
   referenced source is missing or ambiguously resolved. Check for unintended target
   membership changes.
3. **Whole-module typecheck:** typecheck the exact app-target source set using the actual
   target configuration captured in Gate 1 (Swift version, SDK/deployment target, bridging
   header, and available module/framework paths). Compare final diagnostics against the
   saved baseline, preserve and report the compiler process exit status, and do not hide it
   behind a pipeline. If dependencies or the exact configuration are unavailable, mark
   this gate **blocked**, not passed.
4. **Scoped inventory and diff:** confirm the old function-string API and `UIAlertView` are
   absent from the app-target source set, the popup helper is removed, ordinary two-argument
   calls remain compatible, and only intended files changed. Review the complete scoped
   diff against the captured baseline.
5. **Manual regression:** run and record every scenario in the specification, including
   activation once/only after confirmation, the pending-alert upgrade, ordinary Menu
   errors/logout, Home empty basket, all three date guards, and representative login,
   signup, basket/checkout, purchases, and tickets flows. Record named evidence for each
   scenario. If a manual check is not run, leave its checkbox unchecked and label it
   **not run**.

`swiftc -typecheck` is not proof of linking, resources, signing, or runtime behavior. Do not
claim those outcomes from a typecheck. This documentation-only task runs none of these
application gates.

If a gate fails, make only a bounded correction within the approved scope and rerun the
consolidated final gate. Do not reset/stash the worktree, use detached/nohup polling, or
overwrite unrelated edits.

## 3. No-build compile-check recipe

This is a **compiler typecheck, not a build**: it parses and typechecks the app target's
Swift compilation unit without producing an app, object files, or a linked executable.
Run it once before app-source edits and once after the coherent edit batch. The Python
driver below is self-contained, uses only Python 3 and the Xcode command-line tools already
required by the project, resolves source paths from the selected target's PBX Sources phase
(not basenames or a hand-maintained list), and stores the complete source list, build
settings, diagnostics, and compiler exit code under an explicit evidence directory.

The checked-in project was inspected for this plan: target `SwiftCinemas`
(`EA62FD4F1989F6AC00469896`) has one classic Sources phase
(`EA62FD4C1989F6AC00469896`); the test target uses a synchronized group, but the app target
does not. The app target currently declares Swift 6.0, iOS 17.6, and
`SwiftLoginScreen/SwiftLoginScreen-Bridging-Header.h` in its project configuration. These
are inspection notes, not values to hard-code: the driver re-reads the selected
configuration each time and fails if it cannot resolve the target/source model. The
classic phase is explicit, so both new files must appear as sources in that phase after
registration. If the project changes to a synchronized app group, stop and revise the
resolver before using this recipe.

Choose a known, explicit artifact directory and (if needed) a previously populated
`EXISTING_PRODUCTS_DIR` from the exact app target/configuration/SDK. Do not glob DerivedData,
choose the newest directory, build dependencies, or silently restore packages. Do not set
`EXISTING_PRODUCTS_DIR` to a product directory from another target/configuration. If
required modules cannot be imported from the existing checked-in frameworks and explicitly
selected products, report the typecheck as **blocked**.

Run this from the repository root. Set `SWIFT_ARCH` to an architecture present in the
selected target's resolved `ARCHS` (for example `arm64` only when the settings output
confirms it). Set `EXISTING_PRODUCTS_DIR` only when that exact existing directory is
needed. Run the same driver with `ALERT_CHECK_STAGE=baseline` before edits and
`ALERT_CHECK_STAGE=final` after edits; set `VERIFY_ALERT_SOURCES=1` for the final run.

```sh
cd SwiftCinemas
ALERT_CHECK_STAGE=baseline \
ALERT_CHECK_DIR=/tmp/alertcontrollers-evidence \
SWIFT_ARCH=arm64 \
python3 - <<'PY'
import json
import os
import pathlib
import shlex
import subprocess
import sys

project_root = pathlib.Path.cwd().resolve()
project = project_root / "SwiftCinemas.xcodeproj"
pbxproj = project / "project.pbxproj"
scheme_target = "SwiftCinemas"
configuration = os.environ.get("ALERT_CONFIGURATION", "Debug")
sdk_name = os.environ.get("ALERT_SDK", "iphonesimulator")
stage = os.environ["ALERT_CHECK_STAGE"]
evidence = pathlib.Path(os.environ["ALERT_CHECK_DIR"]).expanduser().resolve()
evidence.mkdir(parents=True, exist_ok=True)

def run_capture(args):
    return subprocess.run(args, check=True, text=True, capture_output=True)

# Configuration lookup only. This is not xcodebuild build/test/archive and automatic
# package resolution is disabled; no dependency restore is requested.
settings_result = run_capture([
    "xcodebuild", "-project", str(project), "-target", scheme_target,
    "-configuration", configuration, "-sdk", sdk_name,
    "-showBuildSettings", "-json", "-disableAutomaticPackageResolution",
])
(evidence / f"{stage}.build-settings.json").write_text(settings_result.stdout)
records = json.loads(settings_result.stdout)
records = [r for r in records if r.get("target") == scheme_target]
if len(records) != 1:
    raise SystemExit(f"Expected one {scheme_target} settings record, got {len(records)}")
settings = records[0]["buildSettings"]

# Parse the OpenStep project file using macOS plutil, then walk PBX groups by ID so
# identically named files in different directories cannot silently alias.
project_json = json.loads(run_capture([
    "plutil", "-convert", "json", "-o", "-", str(pbxproj)
]).stdout)
objects = project_json["objects"]
targets = [
    (oid, obj) for oid, obj in objects.items()
    if obj.get("isa") == "PBXNativeTarget" and obj.get("name") == scheme_target
]
if len(targets) != 1:
    raise SystemExit(f"Expected one PBXNativeTarget named {scheme_target}, got {len(targets)}")
target_id, target = targets[0]
if target.get("fileSystemSynchronizedGroups"):
    raise SystemExit("App target now has synchronized source groups; update this resolver first")
source_phases = [
    objects[oid] for oid in target.get("buildPhases", [])
    if objects.get(oid, {}).get("isa") == "PBXSourcesBuildPhase"
]
if len(source_phases) != 1:
    raise SystemExit(f"Expected one explicit app Sources phase, got {len(source_phases)}")
phases = [
    (oid, obj) for oid, obj in objects.items()
    if obj.get("isa") == "PBXProject"
]
main_groups = {obj.get("mainGroup") for _, obj in phases}
if len(main_groups) != 1:
    raise SystemExit("Could not uniquely resolve PBXProject.mainGroup")
resolved_refs = {}

def walk(group_id, parent_dir):
    group = objects[group_id]
    group_dir = parent_dir
    group_path = group.get("path")
    group_tree = group.get("sourceTree", "<group>")
    if group_path:
        if group_tree == "<group>":
            group_dir = parent_dir / group_path
        elif group_tree == "SOURCE_ROOT":
            group_dir = project_root / group_path
        elif group_tree == "<absolute>":
            group_dir = pathlib.Path(group_path)
        else:
            raise SystemExit(f"Unsupported group sourceTree {group_tree}: {group_path}")
    for child_id in group.get("children", []):
        child = objects.get(child_id, {})
        isa = child.get("isa")
        if isa in ("PBXGroup", "PBXVariantGroup"):
            walk(child_id, group_dir)
        elif isa == "PBXFileReference":
            name = child.get("path") or child.get("name")
            if not name:
                continue
            tree = child.get("sourceTree", "<group>")
            if tree == "<group>":
                path = group_dir / name
            elif tree == "SOURCE_ROOT":
                path = project_root / name
            elif tree == "<absolute>":
                path = pathlib.Path(name)
            else:
                path = None
            if path is not None:
                resolved_refs[child_id] = path.resolve()

walk(next(iter(main_groups)), project_root)
swift_sources = []
for build_file_id in source_phases[0].get("files", []):
    build_file = objects.get(build_file_id, {})
    ref_id = build_file.get("fileRef")
    ref = objects.get(ref_id, {})
    if pathlib.PurePosixPath(ref.get("path", ref.get("name", ""))).suffix != ".swift":
        continue
    source = resolved_refs.get(ref_id)
    if source is None:
        raise SystemExit(f"Swift source ref {ref_id} has no resolvable group path")
    if not source.is_file():
        raise SystemExit(f"Missing target Swift source: {source}")
    swift_sources.append(source)
if not swift_sources or len(swift_sources) != len(set(swift_sources)):
    raise SystemExit("Target Swift source list is empty or has duplicate resolved paths")
if os.environ.get("VERIFY_ALERT_SOURCES") == "1":
    expected = {
        project_root / "SwiftLoginScreen/Alerts/AlertAction.swift",
        project_root / "SwiftLoginScreen/Alerts/AlertPresenter.swift",
    }
    absent = expected - set(swift_sources)
    if absent:
        raise SystemExit(f"New alert source(s) not members of app target: {sorted(absent)}")

def required(key):
    value = settings.get(key)
    if not value or "$(" in value:
        raise SystemExit(f"Missing or unresolved target build setting {key}: {value!r}")
    return value

swift_version = required("SWIFT_VERSION").split(".", 1)[0]
deployment = required("IPHONEOS_DEPLOYMENT_TARGET")
architectures = required("ARCHS").split()
arch = os.environ.get("SWIFT_ARCH")
if not arch or arch not in architectures:
    raise SystemExit(f"Set SWIFT_ARCH to one of the resolved ARCHS: {architectures}")
sdk = run_capture(["xcrun", "--sdk", sdk_name, "--show-sdk-path"]).stdout.strip()
cmd = [
    "xcrun", "--sdk", sdk_name, "swiftc", "-typecheck",
    "-swift-version", swift_version, "-sdk", sdk,
    "-target", f"{arch}-apple-ios{deployment}-simulator",
    "-module-cache-path", str(evidence / f"{stage}.module-cache"),
]
bridging = settings.get("SWIFT_OBJC_BRIDGING_HEADER", "")
if bridging:
    bridge_path = pathlib.Path(bridging)
    if not bridge_path.is_absolute():
        bridge_path = project_root / bridge_path
    if not bridge_path.is_file():
        raise SystemExit(f"Missing target bridging header: {bridge_path}")
    cmd += ["-import-objc-header", str(bridge_path)]
for key, flag in (("SWIFT_INCLUDE_PATHS", "-I"), ("FRAMEWORK_SEARCH_PATHS", "-F")):
    for item in shlex.split(settings.get(key, "")):
        if item == "$(inherited)" or "$(" in item:
            continue
        path = pathlib.Path(item)
        if path.exists():
            cmd += [flag, str(path)]
for condition in shlex.split(settings.get("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "")):
    if condition != "$(inherited)" and "$(" not in condition:
        cmd += ["-D", condition]
cmd += shlex.split(settings.get("OTHER_SWIFT_FLAGS", ""))
products = os.environ.get("EXISTING_PRODUCTS_DIR")
if products:
    products_path = pathlib.Path(products).expanduser().resolve()
    if not products_path.is_dir():
        raise SystemExit(f"Explicit EXISTING_PRODUCTS_DIR does not exist: {products_path}")
    cmd += ["-I", str(products_path), "-F", str(products_path)]
cmd += [str(source) for source in swift_sources]
(evidence / f"{stage}.swift-sources.txt").write_text(
    "\n".join(str(source) for source in swift_sources) + "\n"
)
(evidence / f"{stage}.swiftc-command.json").write_text(json.dumps(cmd, indent=2) + "\n")
result = subprocess.run(cmd, text=True, capture_output=True)
(evidence / f"{stage}.swiftc-diagnostics.txt").write_text(
    result.stdout + result.stderr
)
(evidence / f"{stage}.swiftc-exit-status.txt").write_text(f"{result.returncode}\n")
print(f"Target={scheme_target} PBXTarget={target_id}; Swift sources={len(swift_sources)}")
print(f"swiftc -typecheck exit={result.returncode}; evidence={evidence}")
print(result.stdout, end="")
print(result.stderr, end="", file=sys.stderr)
sys.exit(result.returncode)
PY
```

The code block's `SWIFT_ARCH=arm64` is an example, not an assertion about the runner; use
only an architecture confirmed in that run's `ARCHS`. If actual target settings contain
additional required flags/paths that this compact driver does not represent, extend it
from the captured settings before relying on the result. Review baseline diagnostics before
editing. A failed baseline, missing module, unresolved setting, or mismatch between source
membership and files on disk blocks the compiler gate; do not turn it into a pass by
omitting sources or invoking `xcodebuild build`. A successful `swiftc -typecheck` does not
prove linking, resources, signing, or runtime behavior.

## 4. Concrete change examples and bounded handoffs

Examples below are anchored to the inspected source, for implementation planning only. They
are not app edits and do not delegate protected activation/authentication work.

### Shared alert API shape

The current ordinary helper is a `.alert` with an **OK** default action. The typed shape
and call pattern for the extracted presenter are:

```swift
enum AlertAction {
    case none
    case resendActivation
    case custom(() -> Void)
}

extension UIViewController {
    func presentAlert(
        withTitle title: String,
        message: String,
        action: AlertAction = .none
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default) { _ in
            switch action {
            case .none:
                break
            case let .custom(handler):
                handler()
            case .resendActivation:
                // Owner-managed authentication behavior: retain the existing lookup,
                // missing-user behavior, async call, and error handling.
                let storedUser = UserDefaults.standard.value(forKey: "USERNAME")
                Task { @MainActor in
                    guard let user = storedUser as? String else { return }
                    do {
                        try await AuthDataManager.shared.activateCurrentDevice(user: user)
                    } catch {
                        print(error)
                    }
                }
            }
        }
        alert.addAction(ok)
        present(alert, animated: true)
    }
}
```

The `.resendActivation` implementation remains owner-managed because it is authentication
behavior, not mechanical alert plumbing. Its existing behavior is: read
`UserDefaults.standard.value(forKey: "USERNAME")`, silently return if it is not a `String`,
then use `Task { @MainActor in ... }` and
`try await AuthDataManager.shared.activateCurrentDevice(user:)`, preserving its current
error handling. Do not introduce a new request, bypass AppServices-backed services, or alter
URLs, headers, checkout fields, or session semantics. The actual existing manager and
async/await operation are reused unchanged.

### Call-site replacements grounded in the current files

In `MenuVC.presentMenuError`, keep the existing concatenation and dismiss-before-replace
sequence; change only the helper invocation. The current pending-alert branch is:

```swift
let combinedMessage = message
alert.dismiss(animated: false) { [weak self] in
    self?.presentAlertWithFunction(
        withTitle: "Warning!",
        message: combinedMessage,
        function: "sendEmail"
    )
}
```

Replace only the call with:

```swift
self?.presentAlert(
    withTitle: "Warning!",
    message: combinedMessage,
    action: .resendActivation
)
```

Likewise, the direct activation-required branch changes from
`presentAlertWithFunction(withTitle: "Warning!", message: message, function: "sendEmail")`
to `presentAlert(withTitle: "Warning!", message: message, action: .resendActivation)`.
Do not remove the prior `existing + "\n" + message` aggregation or change the
`alert.title != "Warning!"` upgrade guard.

`HomeVC.basket(_:)` currently presents the empty-basket warning through a temporary
alert-level `UIWindow` and labels its action **Close**. Replace only that call:

```swift
guard !BasketDataManager.shared.basketItemsBySeatId.isEmpty else {
    presentAlert(withTitle: "Warning!", message: "No free seat(s) to be reserved!")
    return
}
```

Delete `UIAlertController.popUp` from `Helpers.swift`, but retain its unrelated `String`
and `Date` extensions. The planned **Close** → **OK** text change is explicitly accepted.
For each of the three `VenuesDetailsVC` guards, replace the `UIAlertView` construction with
the same `presentAlert(withTitle: "Warning!", message: "Select dates first!")`; leave the
surrounding `selectedScreeningDateId == nil` condition and `else` path untouched.

### Quick Engineer handoff boundaries

These are bounded handoff templates for a later, separately approved implementation. The
owner runs one coherent edit batch, not one validation cycle per handoff; Quick Engineers
must not run builds, tests, or inter-task inventories. The owning iOS engineer retains all
activation/auth/session behavior, the two `MenuVC` activation call sites, integration,
final review, and the final consolidated gate.

1. **Mechanical extraction (Quick Engineer):** In
   `SwiftCinemas/SwiftLoginScreen/HomeVC.swift`, move only the existing ordinary
   `UIViewController.presentAlert(withTitle:message:)` implementation into
   `SwiftCinemas/SwiftLoginScreen/Alerts/AlertPresenter.swift`; add
   `AlertAction.swift` with `.none`, `.resendActivation`, and `.custom(() -> Void)`, and
   give the presenter `action: AlertAction = .none`. Keep `.alert`, title/message, **OK**,
   default style, animation, and all two-argument call sites. Do not implement the protected
   `.resendActivation` body, touch `MenuVC`, AppServices/auth/networking, or make other
   changes. This is a non-merge-ready slice: the owning iOS engineer must complete and review
   the action branch in the same coherent batch before final validation. Return the exact
   changed-file list and confirm no other API/call-site changes.
2. **Mechanical legacy-dialog cleanup (Quick Engineer):** In
   `HomeVC.basket(_:)`, replace only the empty-basket `UIAlertController.popUp` invocation
   with the shared two-argument helper and preserve the exact warning text/early return.
   In `Helpers.swift`, remove only `UIAlertController.popUp`; retain `String` and `Date`
   extensions. In `VenuesDetailsVC.swift`, replace only the three `UIAlertView` blocks with
   the shared helper, preserving all three nil guards, exact **Warning!** /
   **Select dates first!** text, and continuing `else` branches. No auth, MenuVC, date logic,
   checkout, networking, or project edits. Return only the bounded file changes.
3. **Project-file registration (Quick Engineer, only if the owner requests this mechanical
   subtask):** In `SwiftCinemas/SwiftCinemas.xcodeproj/project.pbxproj`, register
   `SwiftLoginScreen/Alerts/AlertAction.swift` and
   `SwiftLoginScreen/Alerts/AlertPresenter.swift` in the app target `SwiftCinemas`, using
   the verified classic Sources phase `EA62FD4C1989F6AC00469896` and the
   `SwiftLoginScreen` PBX group `EA62FD521989F6AC00469896`. Add two unique
   `PBXFileReference` objects under a new `Alerts` group, two matching `PBXBuildFile`
   objects, the `Alerts` group child to `SwiftLoginScreen`, and both build-file IDs to the
   app Sources phase. Do not modify the test target's synchronized group, frameworks,
   build settings, resources, or any other target membership. Return the four new object
   IDs and the exact membership entries for owner review.

All handoffs require separate implementation authorization. A Quick Engineer must stop and
return a blocker rather than expand scope or alter auth/session contracts. The owner
integrates/reviews the coherent result and runs only the planned baseline and final
verification gates.

## 5. File scope

| Path | Planned action |
|---|---|
| `SwiftCinemas/SwiftLoginScreen/Alerts/AlertAction.swift` | Add typed action enum. |
| `SwiftCinemas/SwiftLoginScreen/Alerts/AlertPresenter.swift` | Add shared UIKit alert helper. |
| `SwiftCinemas/SwiftLoginScreen/HomeVC.swift` | Remove old extension; replace empty-basket popup call. |
| `SwiftCinemas/SwiftLoginScreen/MenuVC.swift` | Replace string callback at all activation-alert paths. |
| `SwiftCinemas/SwiftLoginScreen/Helpers.swift` | Remove `UIAlertController.popUp`; keep unrelated extensions. |
| `SwiftCinemas/SwiftLoginScreen/VenuesDetailsVC.swift` | Migrate three deprecated dialogs. |
| `SwiftCinemas/SwiftCinemas.xcodeproj/project.pbxproj` | Register the two new files only if required by the verified target model. |

No `AppDelegate.swift`, `AppServices`, WebSocket, seat-map, URL/header, checkout, backend,
test, or dependency file is in scope.

## 6. Risks and handling

| Risk | Handling |
|---|---|
| App target does not compile a new alert file | Resolve project target membership first; verify exact PBX references, paths, and target inclusion after edits. |
| Duplicate `UIViewController` helper or temporary incomplete batch | Add new helper and remove old declaration as one paired change; validate only after the complete batch. |
| Activation action changes behavior or fires more than once | Preserve the username guard, confirmation timing, `AuthDataManager` async path, and both `MenuVC` alert flows; manually verify exactly one activation. |
| Concurrent errors cause an overlapping or lost activation alert | Preserve current message combination and dismiss-then-upgrade behavior; exercise it manually. |
| Message or trigger condition changes in venue/date guards | Capture and compare each literal and condition during preflight; verify all three paths manually. |
| Existing unrelated work is included or overwritten | Record baseline status, restrict edits/diff to approved paths, and never reset/stash. |
| Compiler prerequisites are unavailable | Block the gate and report the missing prerequisite; do not substitute an incomplete file list or call it a pass. |
| Spec or implementation reveals a new behavior decision | Stop and record the specific blocker for user resolution; do not silently redesign. |

## 7. Requirement traceability

| Requirement | Planned step / evidence |
|---|---|
| REQ-ALERT-1 | Gate 2.1; helper moved and original extension removed. |
| REQ-ALERT-2 | Gate 2.1 and 2.2; typed action replaces string dispatcher. |
| REQ-ALERT-3 | Gate 2.1 and Gate 3; default argument and unchanged two-argument call sites typecheck. |
| REQ-ALERT-4 | Gate 3; compare default alert style, button, text, and dismissal behavior. |
| REQ-ALERT-5 | Gate 2.2 and manual activation-once scenario. |
| REQ-ALERT-6 | Gate 2.2 and pending-alert/message-aggregation regression. |
| REQ-ALERT-7 | Gate 2.3 and Home empty-basket regression. |
| REQ-ALERT-8 | Gate 2.4, scoped search, and all three date-guard regressions. |
| REQ-ALERT-9 | Gate 1/3 scoped contract review; no auth, networking, URL, header, checkout, or dependency edits. |
| REQ-WS-1 … REQ-WS-9 | Deferred; no tasks or edits in this implementation plan. |
