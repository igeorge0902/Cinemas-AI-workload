# Implementation Plan — Alert Presentation Refactor (iOS)

Source spec: `speckit.migration.alertcontrollers.specify` (REQ-ALERT-1 … REQ-ALERT-7)

**Scope:** alert *presentation* only, **UIKit only**, executed as a **single-pass refactor**.

In scope
- `UIViewController.presentAlert` / `presentAlertWithFunction` extraction and typing
- `UIAlertController.popUp` in `Helpers.swift` — an alert controller serving as an alert dialog
- the 3 remaining `UIAlertView` dialogs in `VenuesDetailsVC`
- all existing `presentAlert` call sites, including registration (`SignupVC`)

Out of scope
- **SwiftUI — no SwiftUI work at all.** **REQ-ALERT-4 (`AlertItem` + `.alert(item:)`) is
  descoped by decision**: the app stays on UIKit. The one SwiftUI screen under
  `SwiftLoginScreen/VenuesMigration/` is not given an alert binding and is not touched. If a
  SwiftUI alert is ever needed, `AlertAction` from S1 is already reusable and an `AlertItem` can
  be added then.
- **WebSocket** requirements of the same spec (REQ-WS-1 … REQ-WS-9) — separate follow-up
- **Popovers**: `PopOver.swift`, `PopOverDates.swift`, `UIPopoverPresentationController` wiring.
  `PopOver.swift:142` contains a `presentAlert` *call site* — it stays source-compatible and is
  not edited.
- **Ad-hoc multi-action / action-sheet `UIAlertController`** in `MapViewController.swift:299,318`,
  `AttendeesVC.swift:69,189`, `iOSCalenderVC.swift:106` — not touched, not reshaped.
- **No new unit tests.** Validation is build + manual regression.

Validation baseline: **`swiftc -typecheck`, not `xcodebuild`** — see §3.1. A full `xcodebuild` run
takes minutes; the typecheck gate is ~18s and catches every error class this refactor can produce.

---

## 1. As-found state (verified in code, 2026-09-26)

The spec's inventory is out of date. Actual state:

| Item | Spec claim | Verified |
|---|---|---|
| `presentAlert` / `presentAlertWithFunction` definition | `HomeVC.swift` | `HomeVC.swift:429-455` (`extension UIViewController`) |
| `presentAlert` call sites | "20" | **36 references across 11 files** |
| `presentAlertWithFunction` call sites | MenuVC only | `MenuVC.swift:62` only — confirmed |
| `UIAlertView` (deprecated) | none expected | **3**: `VenuesDetailsVC.swift:146, 244, 307` |
| Second alert helper | not mentioned | `Helpers.swift:6-16` `UIAlertController.popUp(title:message:)`, one caller: `HomeVC.swift:113` |
| Xcode project membership | manual target edit | **Manual `project.pbxproj` edit IS required.** The `fileSystemSynchronizedGroups` entry (`project.pbxproj:569-571`) belongs to the **`SwiftCinemasTests`** target only. The app target `SwiftCinemas` uses a classic `Sources` build phase (`EA62FD4C1989F6AC00469896`, 72 Swift files) — new files must be added to it or they are silently not compiled. |
| Dead files not in the target | not mentioned | `File.swift`, `CustomURLRequest.swift`, `Networking/SecureStore.swift` are on disk but absent from the Sources phase and **do not typecheck**. Any file-list-by-`find` tooling must exclude them. |

Call-site distribution of `presentAlert*`:

| File | Refs | Action in this refactor |
|---|---|---|
| `MenuVC.swift` | 5 (1 is `presentAlertWithFunction`) | **edit** (S4) |
| `AdminUpdateVC.swift` | 5 | none — compile-verify |
| `SignupVC.swift` | 5 (registration) | none — compile-verify |
| `BasketVC.swift` | 4 | none — compile-verify |
| `LoginVC.swift` | 4 | none — compile-verify |
| `TicketsVC.swift` | 4 | none — compile-verify |
| `VenuesDetailsVC.swift` | 3 | none, but **+3 `UIAlertView` edits** (S6) |
| `AdminVC.swift` | 2 | none — compile-verify |
| `HomeVC.swift` | 2 (the definitions) | **delete extension** (S3) |
| `PopOver.swift` | 1 | none — out of scope, compile-verify |
| `PurchasesVC.swift` | 1 | none — compile-verify |

### Defects to fix as part of the refactor

- **D1 — `MenuVC` presents two alerts.** `MenuVC.swift:55-67`: the
  `.activationRequired(voucherActive: false)` branch calls `presentAlertWithFunction(...)` and then
  *falls through* past the `switch` into `presentAlert(...)`. The second present is issued while the
  first alert is on screen and UIKit drops it. Fixed in S4.
- **D2 — `presentAlertWithFunction` mixes presentation with business logic**: it reads
  `UserDefaults["USERNAME"]` and calls `AuthDataManager.shared.activateCurrentDevice` inline
  (`HomeVC.swift:436-454`), swallowing errors with `print`. Moves behind `AlertAction` in S1.
- **D3 — `UIAlertController.popUp` leaks/loses its window.** It builds a local `UIWindow`, makes it
  key, and never retains it, so the alert can vanish immediately. Removed in S5.

---

## 2. Target design

```
SwiftLoginScreen/Alerts/
├── AlertAction.swift       // enum AlertAction
└── AlertPresenter.swift    // extension UIViewController + top-most presentation
```

- `presentAlert(withTitle:message:action:)` with `action: AlertAction = .none` keeps every existing
  two-argument call site source-compatible (REQ-ALERT-3, REQ-ALERT-5).
- `AlertAction.resendActivation` owns the activation side effect; no `"sendEmail"` string survives
  (REQ-ALERT-2, REQ-ALERT-6).
- UIKit-only: `UIKit` + `UIAlertController`, no `import SwiftUI`, no Podfile change (REQ-ALERT-7).
- No `AlertItem` / `.alert(item:)` — REQ-ALERT-4 is descoped.

---

## 3. Single-pass execution workflow

One pass, one commit-sized change. Steps S1→S7 run in order; nothing is deferred to a second
sweep. To avoid holding call-site inventories in context, **write and re-read scratch files**
instead of re-grepping or memorising:

```bash
WORK=/tmp/alert-refactor            # or the session artifacts dir; NOT the repo
mkdir -p "$WORK"
cd SwiftCinemas/SwiftLoginScreen

# S0 — capture the baseline inventory once, up front
grep -rn "presentAlert" --include=*.swift .      > "$WORK/callsites-before.txt"
grep -rn "UIAlertView" --include=*.swift .       > "$WORK/alertview-before.txt"
grep -rn "popUp(" --include=*.swift .            > "$WORK/popup-before.txt"
grep -rn "presentAlert\|UIAlertView\|popUp(" --include=*.swift . | wc -l \
                                                 > "$WORK/count-before.txt"
```

Then capture the **compile baseline** per §3.1 (`errors-before.txt`, `warnings-before.txt`,
target source count) before editing anything.

At S7 the same commands are re-run into `*-after.txt` and diffed. Do **not** commit `$WORK`.

### 3.1 Compile checking without building the app

**Do not run `xcodebuild` for iteration.** A full build takes minutes. Three cheaper gates, all
verified on this machine (Xcode 26.1 / Swift 6.2.1, 2026-09-26):

| Gate | Command | Time | Catches |
|---|---|---|---|
| G1 syntax | `swiftc -parse`, per file, parallel | **~1.6s** | syntax errors, malformed edits |
| G2 typecheck | `swiftc -typecheck`, whole module | **~18s** | **everything this refactor can break**: duplicate `presentAlert` declarations, wrong signatures, broken call sites, unresolved `AlertAction`, deprecation warnings |
| G3 full build | `xcodebuild` | minutes | linking, resources, codesign — **only once, at the very end, and optional** |

G2 is the real gate. Measured result on the untouched tree: **0 errors, 85 warnings, 18.1s.**

#### Prerequisite: the file list must come from the target, not from `find`

`find . -name '*.swift'` is wrong here — it picks up `File.swift`, `CustomURLRequest.swift` and
`Networking/SecureStore.swift`, which are **not in the app target and do not typecheck** (8
pre-existing errors), plus it trips the duplicate-basename check
(`Networking/SecureStore.swift` vs `DataManagers/SecureStore.swift`).

Write this once into `$WORK/target-sources.py` (verified: resolves all 72 target files):

```python
#!/usr/bin/env python3
"""Swift files in the SwiftCinemas app target's Sources build phase, as on-disk paths.
Run from SwiftCinemas/."""
import os, re, sys

PBX = "SwiftCinemas.xcodeproj/project.pbxproj"
SOURCES_PHASE = "EA62FD4C1989F6AC00469896"  # SwiftCinemas app target
ROOT = "SwiftLoginScreen"
# Basenames that exist more than once on disk; value = the path that is in the target.
AMBIGUOUS = {"SecureStore.swift": "SwiftLoginScreen/DataManagers/SecureStore.swift"}

src = open(PBX).read()
phase = re.search(rf"{SOURCES_PHASE} /\* Sources \*/ = \{{.*?\n\t\t\}};", src, re.S).group(0)
wanted = {n for _, n in re.findall(r"([0-9A-F]{24}) /\* (.+?) in Sources \*/", phase)
          if n.endswith(".swift")}

on_disk = {}
for dirpath, _, files in os.walk(ROOT):
    for f in files:
        if f.endswith(".swift"):
            on_disk.setdefault(f, []).append(os.path.join(dirpath, f))

resolved, problems = [], []
for name in sorted(wanted):
    paths = on_disk.get(name, [])
    if len(paths) == 1:
        resolved.append(paths[0])
    elif name in AMBIGUOUS:
        resolved.append(AMBIGUOUS[name])
    else:
        problems.append(f"{'missing' if not paths else 'ambiguous'}: {name} {paths}")

if problems:
    print("\n".join(problems), file=sys.stderr)
    sys.exit(1)
print("\n".join(resolved))
```

This doubles as the **pbxproj guard**: after S3 adds `Alerts/AlertAction.swift` and
`Alerts/AlertPresenter.swift` to the Sources phase, the script must report **74** files. If it
still reports 72, the pbxproj edit was missed and the new code is not being compiled.

#### G1 — syntax gate (~1.6s)

```bash
cd SwiftCinemas/SwiftLoginScreen
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
find . -name '*.swift' | xargs -P 8 -n 1 -I{} \
  swiftc -parse -sdk "$SDK" -target arm64-apple-ios15.0-simulator {} \
  2>&1 | tee "$WORK/parse.log" | grep 'error:'
```

Run after every file edit. Per-file (`-P 8 -n 1`) avoids the duplicate-basename failure that
whole-module `-parse` hits.

#### G2 — typecheck gate (~18s) — the real check

```bash
cd SwiftCinemas
python3 "$WORK/target-sources.py" > "$WORK/srcs.txt" || exit 1
wc -l < "$WORK/srcs.txt"        # 72 before S3, 74 after

DD=$(ls -dt ~/Library/Developer/Xcode/DerivedData/SwiftCinemas-*/Build/Products/Debug-iphonesimulator | head -1)
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)

swiftc -typecheck -swift-version 5 \
  -sdk "$SDK" -target arm64-apple-ios15.0-simulator \
  -import-objc-header SwiftLoginScreen/SwiftLoginScreen-Bridging-Header.h \
  $(for f in "$DD"/*/; do echo "-I $f -F $f"; done) \
  $(cat "$WORK/srcs.txt") 2>&1 | tee "$WORK/typecheck.log"

grep 'error:'   "$WORK/typecheck.log" | grep -v '^ ' | sort -u > "$WORK/errors.txt"
grep 'warning:' "$WORK/typecheck.log" | grep -v '^ ' | sort -u > "$WORK/warnings.txt"
wc -l "$WORK/errors.txt" "$WORK/warnings.txt"
```

Notes, all empirically determined:
- `-swift-version 5` — the app target is `SWIFT_VERSION = 5.0`; the default Swift 6 mode reports
  spurious concurrency errors.
- `-import-objc-header` — the bridging header is required (AFNetworking etc.).
- `-I`/`-F` into the existing **DerivedData** `Debug-iphonesimulator` products supplies the Pods
  modules (`Realm`, `Braintree`, `Firebase*`, `CryptoSwift`, …). Without it every `import` of a
  pod fails. This reuses a previous build's products — no rebuild.
- iphonesimulator SDK is used because DerivedData holds simulator slices; device SDK would
  require a device-slice build.

**Prerequisite:** DerivedData must already contain a `Debug-iphonesimulator` products dir. If it
is missing or was cleaned, one full `xcodebuild` run is needed to repopulate it — see §3.2.

**Proven to catch the main S3 hazard.** Injecting a second
`extension UIViewController { func presentAlert(withTitle:message:) }` yields:
```
error: invalid redeclaration of 'presentAlert(withTitle:message:)'
```

**Baseline to diff against.** Capture before touching any code, so S7 compares like for like:
```bash
cp "$WORK/errors.txt"   "$WORK/errors-before.txt"     # expect 0 lines
cp "$WORK/warnings.txt" "$WORK/warnings-before.txt"   # expect 85 lines, 9 UIAlertView-related
```
The 9 `UIAlertView` deprecation warnings at `VenuesDetailsVC.swift:146,244,307` must be **gone**
after S6 — that is the machine-checkable proof for that step.

### 3.2 If a full `xcodebuild` is unavoidable

Only if DerivedData is empty, or as one optional final confirmation. Never block on it
interactively — run it detached, tail the log, and poll:

```bash
cd SwiftCinemas
nohup xcodebuild -workspace SwiftCinemas.xcworkspace -scheme SwiftCinemas \
  -configuration Debug -destination 'generic/platform=iOS simulator' \
  -derivedDataPath ~/Library/Developer/Xcode/DerivedData/SwiftCinemas-build \
  build > "$WORK/build.log" 2>&1 &
echo $! > "$WORK/build.pid"
```

Poll instead of waiting:
```bash
tail -n 40 "$WORK/build.log"
grep -E 'error:|BUILD (SUCCEEDED|FAILED)' "$WORK/build.log" | tail -20
kill -0 "$(cat "$WORK/build.pid")" 2>/dev/null && echo RUNNING || echo DONE
```

Keep working on unrelated steps between polls. Stop with `kill "$(cat "$WORK/build.pid")"` if it
is no longer needed. `$WORK/build.log` is never committed.

---

## 4. Steps

### S1 — `Alerts/AlertAction.swift` (new)

Requirements: REQ-ALERT-2, REQ-ALERT-7. Fixes D2.

```swift
// AlertAction.swift
import UIKit

/// Typed replacement for the former `function: String` parameter ("sendEmail").
enum AlertAction {
    case none
    case resendActivation
    case custom(() -> Void)

    /// Side effect to run when the user confirms. `nil` == plain dismiss.
    @MainActor
    var handler: (() -> Void)? {
        switch self {
        case .none:
            return nil

        case .resendActivation:
            return {
                guard let user = UserDefaults.standard.string(forKey: "USERNAME") else {
                    NSLog("AlertAction.resendActivation: no USERNAME in UserDefaults")
                    return
                }
                Task { @MainActor in
                    do {
                        try await AuthDataManager.shared.activateCurrentDevice(user: user)
                    } catch {
                        NSLog("AlertAction.resendActivation failed: %@", error.localizedDescription)
                    }
                }
            }

        case let .custom(block):
            return block
        }
    }
}
```

Done when: compiles; the activation side effect exists in exactly one place; no `"sendEmail"`
literal anywhere (`grep -rn '"sendEmail"' .` is empty).

---

### S3 — `Alerts/AlertPresenter.swift` (new) + remove the extension from `HomeVC.swift`

Requirements: REQ-ALERT-1, REQ-ALERT-3, REQ-ALERT-5. These two edits **must land together** —
otherwise the `UIViewController` extension is declared twice and nothing compiles.

```swift
// AlertPresenter.swift
import UIKit

extension UIViewController {

    /// Default `.none` reproduces the previous HomeVC behaviour exactly:
    /// single "OK" action, `.default` style, `.alert` presentation.
    func presentAlert(withTitle title: String,
                      message: String,
                      action: AlertAction = .none) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        let handler = action.handler
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in handler?() })

        // Presenting on a controller that is already presenting is silently dropped by UIKit
        // (this is what hid MenuVC's second alert). Always present from the top-most controller.
        AlertPresenter.topMostViewController(from: self)?.present(alert, animated: true)
    }
}

enum AlertPresenter {

    /// Entry point for non-`UIViewController` contexts, replacing
    /// `UIAlertController.popUp` and its detached `UIWindow`.
    @MainActor
    static func present(title: String, message: String, action: AlertAction = .none) {
        keyWindowRoot()?.presentAlert(withTitle: title, message: message, action: action)
    }

    static func topMostViewController(from controller: UIViewController?) -> UIViewController? {
        var current = controller
        while let presented = current?.presentedViewController {
            current = presented
        }
        return current
    }

    private static func keyWindowRoot() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
```

`HomeVC.swift` — delete the whole trailing block:

```swift
// DELETE HomeVC.swift:429-455
extension UIViewController {
    func presentAlert(withTitle title: String, message: String) { ... }
    func presentAlertWithFunction(withTitle title: String, message: String, function: String) { ... }
}
```

**Also register both new files in the app target's `Sources` build phase** — the app target does
**not** use a synchronized group (see §1). Add to `project.pbxproj`:
- a `PBXFileReference` and `PBXBuildFile` for `Alerts/AlertAction.swift` and
  `Alerts/AlertPresenter.swift`,
- an `Alerts` `PBXGroup` (path `SwiftLoginScreen/Alerts`, `sourceTree = SOURCE_ROOT`, matching the
  existing `DataManagers` group at `project.pbxproj:290-306`),
- both `… in Sources` entries inside phase `EA62FD4C1989F6AC00469896`.

Easiest safe route: add the files via Xcode's UI (target checkbox ticked) rather than hand-editing.

Done when: `grep -n "extension UIViewController" HomeVC.swift` is empty,
`grep -rn "presentAlertWithFunction" .` is empty after S4, and
`python3 "$WORK/target-sources.py" | wc -l` reports **74** (was 72).

---

### S4 — `MenuVC.swift` activation path (edit) — REQ-ALERT-6, fixes D1

Before (`MenuVC.swift:57-73`) — two alerts on the activation branch:

```swift
} catch let err as AppError {
    let title: String
    switch err {
    case .activationRequired(voucherActive: false):
        title = "Warning!"
        self.presentAlertWithFunction(withTitle: title, message: ErrorHandler.message(for: err), function: "sendEmail")
    default:
        title = "No valid session!"
    }
    self.presentAlert(withTitle: title, message: ErrorHandler.message(for: err))   // ← also runs for the activation case
}
```

After — exactly one alert per branch:

```swift
} catch let err as AppError {
    switch err {
    case .activationRequired(voucherActive: false):
        self.presentAlert(withTitle: "Warning!",
                          message: ErrorHandler.message(for: err),
                          action: .resendActivation)
    default:
        self.presentAlert(withTitle: "No valid session!",
                          message: ErrorHandler.message(for: err))
    }
}
```

The remaining `MenuVC` alerts (`:70` network error, `:235` logout success, `:239` logout failure)
are unchanged.

Done when: no `presentAlertWithFunction` remains; activation-required shows one alert whose OK
triggers activation.

---

### S5 — `Helpers.swift` `popUp` → `AlertPresenter` (edit) — fixes D3

Single caller. `HomeVC.swift:111-115`:

```swift
@IBAction func basket(_: UIButton) {
    guard !BasketDataManager.shared.basketItemsBySeatId.isEmpty else {
-       UIAlertController.popUp(title: "Warning!", message: "No free seat(s) to be reserved!")
+       presentAlert(withTitle: "Warning!", message: "No free seat(s) to be reserved!")
        return
    }
```

Then delete `Helpers.swift:6-16` (`extension UIAlertController { static func popUp… }`) entirely.
The other `Helpers.swift` extensions (`String.formatDate`, `Date`, …) stay untouched.
Any future non-VC caller uses `AlertPresenter.present(title:message:)` from S3.

> Note the button title changes from "Close" to "OK", matching every other alert in the app.

Done when: `grep -rn "popUp(" --include=*.swift .` is empty.

---

### S6 — `VenuesDetailsVC.swift` — remove the 3 `UIAlertView` dialogs (edit)

Spec success criterion: *"No UIAlertView usage exists anywhere in the codebase."*
Identical block at lines **146**, **244** and **307**:

```swift
-   let alertView = UIAlertView()
-
-   alertView.title = "Warning!"
-   alertView.message = "Select dates first!"
-   alertView.delegate = self
-   alertView.addButton(withTitle: "OK")
-   alertView.show()
+   presentAlert(withTitle: "Warning!", message: "Select dates first!")
```

> Line 146's message is `"Select dates first!"` — copy each title/message verbatim from
> `$WORK/alertview-before.txt` rather than assuming all three are identical.

`VenuesDetailsVC` declares no `UIAlertViewDelegate` conformance (line 8), so only the
`alertView.delegate = self` assignments disappear — no protocol conformance to remove.

Done when: `grep -rn "UIAlertView" --include=*.swift .` is empty and
`grep -c UIAlertView "$WORK/warnings.txt"` is 0 (was 9) after the G2 typecheck gate.

---

### S7 — Validate

**S7a — Compile check (no app build)**

Run the G2 typecheck gate from §3.1 and diff against the captured baseline:

```bash
diff "$WORK/errors-before.txt"   "$WORK/errors.txt"      # must stay at 0 errors
diff "$WORK/warnings-before.txt" "$WORK/warnings.txt"    # only expected removals
grep -c UIAlertView "$WORK/warnings.txt"                 # must be 0 (was 9)
python3 "$WORK/target-sources.py" | wc -l                # must be 74 (was 72)
```

Pass criteria:
- `$WORK/errors.txt` is empty;
- the only warning-diff entries are **removals** — the 9 `UIAlertView` deprecations from
  `VenuesDetailsVC.swift:146,244,307`; no warnings added;
- the target source count is 74, proving S3's pbxproj registration landed.

If a *call site* fails to typecheck, fix the presenter signature — never the call site
(REQ-ALERT-5).

No `xcodebuild` run is required for this refactor. It touches no resources, storyboards, build
phases beyond the two Sources entries, or dependencies, so the typecheck gate is sufficient. Run a
full build per §3.2 only if you want one final confirmation — detached, logged and polled.

**S7b — Inventory diff**
```bash
cd SwiftCinemas/SwiftLoginScreen
grep -rn "presentAlert" --include=*.swift . > "$WORK/callsites-after.txt"
diff "$WORK/callsites-before.txt" "$WORK/callsites-after.txt" > "$WORK/callsites.diff"
grep -rn "UIAlertView\|popUp(\|presentAlertWithFunction\|\"sendEmail\"" --include=*.swift . \
  > "$WORK/legacy-after.txt"   # MUST be empty
```
`callsites.diff` must show changes only in `MenuVC.swift`, `HomeVC.swift` and
`VenuesDetailsVC.swift` (the last as *additions*).

**S7c — Manual regression** (no automated coverage exists for these flows; no tests are added)

| Flow | Expected |
|---|---|
| MenuVC — activation required | **one** alert; OK triggers device activation |
| MenuVC — session error / network error | one alert each, unchanged text |
| MenuVC — logout success / failure | unchanged |
| HomeVC — basket with empty basket (S5) | "No free seat(s) to be reserved!", OK button |
| VenuesDetailsVC — seat tap, `selectCalendar`, `selectCalendar_` without a date (S6) | "Select dates first!" alert appears and dismisses |
| SignupVC — registration: missing fields, password mismatch, server error, connection failure | unchanged |
| LoginVC — sign-in failure paths | unchanged |
| BasketVC — empty basket, payment success, booking failed, payment error | unchanged |
| AdminVC / AdminUpdateVC — duplicate id, add/update/delete | unchanged |
| PurchasesVC delete, TicketsVC share/delete guards | unchanged |
| PopOver — reserve with empty basket | unchanged (out of scope) |

**S7d — Spec reconciliation**
Update `speckit.migration.alertcontrollers.specify`: "20 existing call sites" → 36; mark
REQ-ALERT-4 and its "`AlertItem` usable in any SwiftUI view" success criterion as **descoped
(UIKit-only decision)**; note the WebSocket half (REQ-WS-*) is tracked separately.

**S7e — Cleanup**
Remove `$WORK` once S7a–S7d pass. It must never be committed.

---

## 5. Order and coupling

```
S0 (inventory + compile baseline)
 └─> S1 ─> S3 (+ HomeVC extension deletion + pbxproj, same change)
              ├─> S4  MenuVC
              ├─> S5  popUp
              └─> S6  UIAlertView
                   └─> S7 typecheck + diff + manual
```

Run the **G1 syntax gate (~1.6s) after every file edit**; run the **G2 typecheck gate (~18s) once
after S6**, when the tree is expected to be consistent. Running G2 between S3 and S6 is fine but
will report transient errors — that is expected in a single pass.

S3, the `HomeVC` deletion and the pbxproj registration are atomic. S4/S5/S6 are independent of each
other and are all part of the same single pass — the tree is only expected to typecheck clean at
the end of S6.

---

## 6. Risks

| Risk | Mitigation |
|---|---|
| **New files not added to the app target's `Sources` phase** → code silently not compiled, refactor appears to work | S3 pbxproj step; `target-sources.py` count must go 72 → 74 (S7a) |
| Duplicate `UIViewController.presentAlert` declarations mid-pass | S3 pairs the new file with the `HomeVC` deletion in one edit; G2 typecheck reports `invalid redeclaration` (verified) |
| Feeding dead files (`File.swift`, `CustomURLRequest.swift`, `Networking/SecureStore.swift`) to `swiftc` → 8 phantom errors | File list comes from the pbxproj Sources phase, never from `find` (§3.1) |
| DerivedData cleaned → G2 cannot resolve Pods modules | Detected immediately as `no such module 'Realm'`; repopulate with one detached build per §3.2 |
| Behaviour drift in the default path (button title/style) | S3 reproduces `HomeVC.swift:430-434` exactly |
| `VenuesDetailsVC` relied on `UIAlertView`'s implicit window-level presentation | top-most presentation in S3 covers the popover-presented cases; S7c exercises all three |
| Wrong title/message copied in S6 | Values taken from `$WORK/alertview-before.txt`, not memory |
| `popUp`'s "Close" button label change | Accepted and documented in S5 |
| Scope creep into SwiftUI / popovers / action sheets / WebSocket | Explicitly excluded in §Scope; no `import SwiftUI` in the new files; `VenuesMigration/`, `MapViewController`, `AttendeesVC`, `iOSCalenderVC`, `PopOver*` untouched |

---

## 7. Traceability

| Requirement | Step |
|---|---|
| REQ-ALERT-1 Move helpers out of `HomeVC.swift` | S3 |
| REQ-ALERT-2 Typed `AlertAction` | S1 |
| REQ-ALERT-3 Default-parameter signature | S3 |
| REQ-ALERT-4 SwiftUI `AlertItem` | **descoped — UIKit-only decision, 2026-09-26** |
| REQ-ALERT-5 Existing call sites compile unchanged | S7a, S7b |
| REQ-ALERT-6 `MenuVC` uses `.resendActivation` | S4 |
| REQ-ALERT-7 No new dependency | S1, S3 (UIKit only, no Podfile change) |
| Success criterion — no `UIAlertView` | S6 |
| Success criterion — "AlertItem usable in any SwiftUI view" | **descoped with REQ-ALERT-4** |
| Success criterion — no regressions | S7c |
