# UIKit Alert Presentation Migration

**Status:** REQ-ALERT-1..9 implemented with explicit user approval; scoped static checks
passed. Manual regressions are not run.
**Related artifacts:** [Implementation plan](speckit.migration.alertcontrollers.implementation-plan.md) · [Task checklist](speckit.migration.alertcontrollers.tasks.md)

## Approved implementation scope and evidence — 2026-10-17

The user explicitly approved application edits and task-file-only inspection/compiler
checks: “you should target only the files in this task” and “that is also about the
compile. you are cleared to proceed”. The user reported the app had already been built
and run with Carthage for the Braintree update and ran successfully; that is the accepted
readiness baseline, **reported by the user, not independently rerun**. Earlier whole-module
baseline/typecheck gates are superseded. No dependency investigation/restoration,
whole-target compile/Xcode build, or WebSocket checks are authorized by this task.

The six task Swift files passed syntax parsing; `AlertAction.swift` alone passed
typechecking. These are not a presenter/controller or whole-module typecheck. Exact
app-only PBX membership and the complete task-baseline diff passed review; pre-existing
project/document changes were preserved. The typed action retains the existing activation
body inside the OK handler, both Menu paths, and all three venue guards. Home's accepted
**Close** → **OK** change is implemented. Manual scenarios below remain **not run**.
Commands, limits, and results are recorded in the implementation plan.

## Purpose

Consolidate the app's existing UIKit alert helpers, remove the remaining deprecated
`UIAlertView` dialogs, and replace an untyped activation callback with an explicit action.
Keep the change limited to alert presentation and preserve the existing user-facing
messages and activation request behavior.

## Scope

### In scope

- Move the `UIViewController` alert helper out of `HomeVC.swift` into
  `SwiftCinemas/SwiftLoginScreen/Alerts/AlertPresenter.swift`.
- Add a typed `AlertAction` in `SwiftCinemas/SwiftLoginScreen/Alerts/AlertAction.swift`.
- Migrate `MenuVC` activation-alert paths to that typed action, preserving the current
  pending-alert/message-combination behavior.
- Replace the single `UIAlertController.popUp` call in `HomeVC` with the shared UIKit
  presenter and remove the redundant helper.
- Replace the three `UIAlertView` dialogs in `VenuesDetailsVC` with the shared helper.
- Register both new Swift files in the **app target**, using the project structure verified
  during implementation preflight.

### Explicitly deferred

- **SwiftUI alerts:** `AlertItem` and `.alert(item:)` are not part of this UIKit-only change.
  There is no SwiftUI alert consumer in this task. Revisit if a concrete SwiftUI alert use
  case is approved.
- **WebSocket messages:** all `REQ-WS-*` requirements below are retained for traceability but
  deferred to a separate feature. This change does not alter `WebSocketManager`,
  `SeatsVC`, `AppServices`, or message handling.
- Existing action sheets, popovers, and bespoke multi-action `UIAlertController` flows are
  unchanged.
- No backend, networking, authentication, checkout, or dependency changes.

## As-found evidence

The source was inspected for this documentation update; this is not a fresh build or a
pre-implementation inventory:

- `HomeVC.swift` currently defines `presentAlert(withTitle:message:)` and
  `presentAlertWithFunction(...function:)` in a `UIViewController` extension. The normal
  helper presents a UIKit alert with one **OK** action.
- The string `"sendEmail"` selects an activation callback. On confirmation it reads
  `UserDefaults["USERNAME"]` and calls
  `AuthDataManager.shared.activateCurrentDevice(user:)` asynchronously on the main actor.
- `MenuVC.presentMenuError` has both a direct activation-required path and a path that
  dismisses/upgrades an already-presented error alert. It also combines concurrent error
  messages rather than presenting overlapping alerts. Preserve these behaviors; the older
  plan's claim that the activation switch unconditionally presents two alerts is stale.
- `AuthDataManager` is an existing `HasAppServices` data manager injected at app startup by
  `AppDelegate`. Its activation operation already uses async/await through the existing
  login service. Reuse it; do not create a new client or duplicate the activation request.
- `Helpers.swift` defines `UIAlertController.popUp`; its only identified caller is the empty
  basket guard in `HomeVC`. That helper uses a **Close** action.
- `VenuesDetailsVC.swift` has three `UIAlertView` guards with title **Warning!**, message
  **Select dates first!**, and an **OK** button.
- The current PBX project configuration must be resolved again at implementation time.
  Do not rely on old source counts, line numbers, IDs, or DerivedData measurements.

## Requirements

### UIKit alerts

**REQ-ALERT-1 — Extract shared helper.** Move the existing
`presentAlert(withTitle:message:)` behavior out of `HomeVC.swift` into
`Alerts/AlertPresenter.swift`. `HomeVC.swift` must no longer define the `UIViewController`
extension for this helper.

**REQ-ALERT-2 — Use a typed action.** Define `AlertAction` with at least `.none`,
`.resendActivation`, and `.custom(() -> Void)` cases. Remove the string-based
`presentAlertWithFunction(...function:)` API and its `"sendEmail"` dispatch.

**REQ-ALERT-3 — Keep the default call source-compatible.** The shared helper accepts
`action: AlertAction = .none`; all existing ordinary two-argument
`presentAlert(withTitle:message:)` call sites remain valid without edits.

**REQ-ALERT-4 — Preserve ordinary alert behavior.** With `.none`, keep the existing title,
message, alert style, **OK** label, default action style, and dismissal behavior.

**REQ-ALERT-5 — Preserve activation semantics.** `.resendActivation` runs only after the
user confirms. It uses the existing username lookup and `AuthDataManager` async activation
path, executes on the main actor as required, and preserves existing missing-user and error
handling. It must not initiate duplicate activation requests.

**REQ-ALERT-6 — Migrate all activation paths.** Update every `MenuVC` use of the old
string-based helper, including the direct activation-required case and the pending-alert
upgrade callback. Preserve combined error text, dismissal-before-replacement, and the
single-alert-at-a-time behavior.

**REQ-ALERT-7 — Remove duplicate helper route.** Replace the `HomeVC` empty-basket
`UIAlertController.popUp` call with the shared helper and remove the unused `popUp`
extension. Preserve its title and message. The **Close** to **OK** action-label change is
intentional; do not create a detached-window or second presentation mechanism.

**REQ-ALERT-8 — Remove deprecated dialogs.** Migrate all three `UIAlertView` uses in
`VenuesDetailsVC` to the shared helper, preserving each existing title, message, guard
condition, and dismissal behavior. No `UIAlertView` remains in the Swift app target.

**REQ-ALERT-9 — Preserve app/network contracts.** Do not change AppServices wiring,
authentication semantics, request URLs, header names, checkout fields, or backend payloads.
No third-party dependency is added.

### Deferred WebSocket requirements (not acceptance criteria for this feature)

The following inherited requirements are recorded for a separately scoped follow-up only:

- **REQ-WS-1:** Publish incoming WebSocket messages.
- **REQ-WS-2:** Model typed WebSocket message variants.
- **REQ-WS-3:** Parse and publish received messages.
- **REQ-WS-4:** Handle the documented seat-update payload and unknown formats.
- **REQ-WS-5:** Refresh the selected screening's seat map on matching updates.
- **REQ-WS-6:** Use non-modal feedback for seat updates.
- **REQ-WS-7:** Present generic notifications appropriately.
- **REQ-WS-8:** Preserve reconnect behavior.
- **REQ-WS-9:** Continue using `URLSessionWebSocketTask`.

## Acceptance criteria

- Both new alert source files are members of the verified SwiftCinemas **app** target.
- The default two-argument helper remains callable across existing screens.
- The activation action appears on the confirmation alert only, and activation behavior is
  unchanged.
- `MenuVC` retains the existing alert aggregation/upgrade flow without overlapping alerts.
- `HomeVC` empty-basket feedback uses the shared helper; the legacy `popUp` helper is gone.
- The three date-guard alerts in `VenuesDetailsVC` retain their text and trigger conditions.
- No `UIAlertView` or `presentAlertWithFunction` remains in the app-target source inventory.
- Checkout, authentication, URL, and header contracts are untouched.
- Task-file syntax and exact target membership gates pass; feasible isolated compiler
  checks are recorded separately from typechecking the presenter/controllers. No whole-module
  typecheck or Xcode build is run under the approved scope.
- Legacy API absence is verified in the scoped files only, not claimed as a new whole-app
  inventory. Manual regressions are recorded as **not run**, not passed.

## Manual regression scenarios

After implementation, verify at minimum:

1. `MenuVC`: direct activation-required error shows one warning alert; confirming starts
   activation once.
2. `MenuVC`: activation-required error arriving while another error is presented upgrades
   the alert after dismissal and preserves the combined message.
3. `MenuVC`: ordinary errors and logout success/failure retain their messages and behavior.
4. `HomeVC`: empty basket shows the same warning text and dismisses with **OK**.
5. `VenuesDetailsVC`: all three date-required guards show the existing warning text and
   dismiss with **OK**.
6. Existing login, signup, basket/checkout, purchases, tickets, and other ordinary alert
   flows remain unchanged.
