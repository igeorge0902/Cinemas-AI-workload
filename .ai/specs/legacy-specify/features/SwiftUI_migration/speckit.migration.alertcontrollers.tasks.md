# Tasks — UIKit Alert Presentation Migration

**Specification:** [Alert-controller specification](speckit.migration.alertcontrollers.specify.md)
**Plan:** [Implementation plan](speckit.migration.alertcontrollers.implementation-plan.md)
**Status:** T0–T6 completed within the explicitly narrowed scope; T7 manual checks **not run**.
Application changes were approved and implemented. See the plan's dated execution record
for exact commands/results, retained dirty baseline, and PBX IDs.

**Scope override (2026-10-17):** User approval covers task files only, including inspection
and compile checks. The user-reported successful Carthage/Braintree build/run establishes
T1 readiness; it was not independently rerun. Earlier whole-module baseline/typecheck
requirements and dependency investigation are superseded. No target build, dependency
restore, WebSocket checks, delegation, commit, or push was performed.

## Ordered tasks

### T0 — Obtain application-edit approval

- [x] Obtain separate user approval to edit SwiftCinemas application source/project files.
- [x] Confirm the approved scope remains UIKit alert presentation only; no WebSocket, SwiftUI,
  backend, networking, dependency, commit, or push work.

**Acceptance:** Approval is explicit and the file scope in the linked plan is unchanged.

### T1 — Capture implementation preflight

**Depends on:** T0

- [x] Record baseline working-tree status and scoped diff; identify pre-existing edits and
  preserve unrelated/user-owned changes.
- [x] Inventory scoped helper declarations/call sites, activation paths, popup usage, and
  deprecated dialogs with their exact messages and conditions.
- [x] Resolve the actual Xcode app target, declared configuration, source-membership model, PBX
  object IDs, and on-disk paths; detect duplicate or missing resolutions.
- [x] Accept the user's successful build/run as readiness baseline; inspect task-local
  PBX settings/membership only. Do not execute the superseded §3 recipe, dependency
  investigation, whole-target compile/typecheck, or Xcode build.
- [x] Record intended edits and the manual regression cases before changing source.

**Acceptance:** User-reported readiness and scoped dirty baseline recorded; task-file
membership is unambiguous. No new dependency readiness claim is made.

### T2 — Add the typed action and shared presenter

**Depends on:** T1

- [x] Add `Alerts/AlertAction.swift` with `.none`, `.resendActivation`, and `.custom` cases.
- [x] Add `Alerts/AlertPresenter.swift` with the shared UIKit helper and a default `.none`
  action that preserves the ordinary two-argument call.
- [x] Preserve the existing default alert style, text, **OK** action, and dismissal behavior.
- [x] Remove the old `UIViewController` helper extension from `HomeVC.swift` in the same
  coherent edit batch.
- [x] Register both new files in the app target using the Gate 1-resolved PBX layout.
- [x] Not applicable: no Quick Engineer or other delegation used. If using the plan's bounded Quick Engineer handoff, keep its scope to mechanical
  extraction and the `.resendActivation` enum case declaration. The owning iOS engineer
  implements/reviews the action body and integration; no auth/session work is delegated.

**Acceptance:** There is one shared helper declaration, ordinary call sites remain source
compatible, and both files resolve to the intended app-target membership.

### T3 — Migrate Menu activation alert paths

**Depends on:** T2

- **Owner:** Owning iOS engineer only; this is protected authentication behavior, not a
  Quick Engineer handoff.
- [x] Replace every `presentAlertWithFunction(...function: "sendEmail")` use with the typed
  `.resendActivation` action.
- [x] Preserve the existing username lookup, `AuthDataManager` async activation operation,
  main-actor execution, missing-user/error behavior, and confirmation timing.
- [x] Preserve both the direct activation-required alert and the pending-alert dismissal/
  upgrade flow, including combined messages and single-alert-at-a-time behavior.

**Acceptance:** No string-dispatched helper remains; activation runs only after confirmation
and no more than once per confirmed alert.

### T4 — Remove the redundant HomeVC popup helper

**Depends on:** T2

- [x] Replace the empty-basket `UIAlertController.popUp` call with the shared helper.
- [x] Remove only the `UIAlertController.popUp` extension from `Helpers.swift`; leave
  unrelated helpers intact.
- [x] Preserve the warning title/message. Record the accepted **Close** to **OK** label
  change in the regression evidence.

**Acceptance:** The empty-basket guard still presents its warning through the shared UIKit
path and no popup helper/call remains.

### T5 — Migrate VenuesDetailsVC deprecated dialogs

**Depends on:** T2

- [x] Replace each of the three `UIAlertView` blocks with the shared helper.
- [x] Preserve every captured title, message, trigger condition, and dismiss behavior.
- [x] Not applicable: no delegation used. If using a Quick Engineer, use only the bounded `HomeVC`/`Helpers.swift`/
  `VenuesDetailsVC.swift` handoff in plan §4; do not delegate the `MenuVC` activation path.

**Acceptance:** No `UIAlertView` use remains in the scoped source inventory and all
three date-required guards remain intact.

### T6 — Run consolidated static and no-build compile gates

**Depends on:** T3, T4, T5

- [x] Parse all six task Swift sources using installed Xcode Swift 6 / iOS Simulator SDK,
  explicit `arm64-apple-ios17.6-simulator` target: exit 0 (syntax only).
- [x] Verify exact PBX target membership and resolved repo-relative paths for both new files;
  confirm no missing or duplicate source resolution or unintended target change.
- [x] Run feasible isolated compiler check: `AlertAction.swift` typecheck with explicit
  Simulator SDK/target exited 0. Initial invocation without explicit SDK/target exited 1
  due to a sysroot/target mismatch; corrected command passed without source edits.
  Presenter/controller and whole-module typechecks **not run** under the scope override.
- [x] Compare scoped inventories and complete diff to the retained preflight baseline. Verify ordinary
  two-argument calls, no old activation helper, no popup helper, and no `UIAlertView`.
- [x] Confirm no auth, networking, URL, header, checkout, backend, or dependency contract
  changed.

**Acceptance:** Scoped syntax, isolated enum typecheck, exact membership, source comparisons,
and diff review passed; only approved files changed from the retained dirty baseline.
No app build or whole-target gate is part of the narrowed check. Syntax is not typecheck;
enum-only typecheck does not prove presenter/controller compilation or runtime behavior.

### T7 — Run and record manual regressions

**Depends on:** T6

- [ ] `MenuVC` direct activation-required case: one alert; confirmation starts one activation.
- [ ] `MenuVC` pending-alert upgrade: dismissal precedes replacement; combined message is
  preserved; activation remains confirmation-only.
- [ ] `MenuVC` ordinary errors and logout success/failure remain unchanged.
- [ ] `HomeVC` empty basket: warning text remains; **OK** dismisses.
- [ ] `VenuesDetailsVC` date guards: all three paths show the original warning and dismiss.
- [ ] Representative existing login, signup, basket/checkout, purchases, and tickets alert
  flows remain unchanged.

**Acceptance:** Record named evidence for each scenario. Any scenario not run stays
unchecked and is explicitly marked **not run**; do not claim the overall manual gate passed.

## Requirement traceability

| Spec requirement | Task(s) |
|---|---|
| REQ-ALERT-1 — extract helper | T2 |
| REQ-ALERT-2 — typed action | T2, T3 |
| REQ-ALERT-3 — compatible default signature | T2, T6 |
| REQ-ALERT-4 — preserve ordinary alert behavior | T2, T7 |
| REQ-ALERT-5 — preserve activation semantics | T3, T7 |
| REQ-ALERT-6 — migrate all activation paths | T3, T7 |
| REQ-ALERT-7 — remove popup route | T4, T7 |
| REQ-ALERT-8 — migrate deprecated dialogs | T5, T7 |
| REQ-ALERT-9 — preserve app/network contracts | T1, T6 |
| REQ-WS-1 … REQ-WS-9 — WebSocket behavior | Deferred; no task in this feature |
| SwiftUI `AlertItem` | Deferred; no task in this feature |
