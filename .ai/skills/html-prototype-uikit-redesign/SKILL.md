# HTML Prototype to UIKit Redesign

## Purpose
Translate HTML prototype screens into production UIKit implementations in this repository while preserving existing backend/data contracts, segue routes, and notification contracts.

## Use When
- You need to implement or refine UIKit screen design from one or more HTML prototypes.
- You need visual parity improvements (layout, spacing, typography, interactions) without backend/API changes.
- You are working on these screens: `AdminVC`, `AdminUpdateVC`, `MenuVC`, `PurchasesVC`, `TicketsVC`.

## Do Not Use When
- The task is backend endpoint design or contract changes.
- The task is full SwiftUI migration (this skill is UIKit-focused).
- You do not have target prototype files and cannot infer expected states safely.

## Inputs
- Required: prototype HTML file paths.
- Required: target UIKit file paths.
- Required: related Speckit docs (`analyze`, `plan`, `specify`, `tasks`, optional `uikit-draft`).
- Optional: known simulator issues (clipping, unsafe constraints, popover behavior).

## Outputs
- Per-screen gap list (expected vs current).
- Concrete UIKit patch plan (minimal-risk, contract-safe).
- Implemented code changes with file-level validation.
- Optional review artifacts (SVG wireframes / comparison notes).

## Constraints
- Keep payload keys, notifications, and segue IDs unchanged.
- Keep navigation route behavior unchanged.
- Keep existing DataManager/BackendServices contracts unchanged.
- Prefer programmatic Auto Layout for reliable safe-area behavior when storyboard geometry is unstable.
- Use storyboard for navigation wiring only when practical.

## Prototype Sources (Repository)
- Main source folder: `/Users/gyorgy.gaspar/work/cinemas/cinemas/.ai/workflows/features/SwiftUIFeatures/prototypes`
- Reference first for admin redesign: `adminvc-adminupdate-redesign.prototype.html`
- Reference for menu/purchases/tickets styling: `menuvc-purchasesvc-ticketsvc-adminstyle.prototype.html`

## Admin/AdminUpdate Learned Patterns
- Build sectioned card layout in UIKit when storyboard constraints drift on simulator sizes.
- Rebuild scroll content programmatically and remove stale storyboard subviews in the scroll container before laying out cards.
- Use safe-area + scroll content/frame guides to prevent top clipping and off-screen bottom content.
- Keep update-only fields visually read-only and clearly differentiated from editable inputs.
- For selector popovers, mirror prototype behavior: bordered search, compact rows, selected-row highlight, and long-press expansion where specified.
- Preserve event contracts (`NotificationCenter` names, segue IDs, selection payloads) while changing only presentation/layout.

## Workflow
1. Collect and read all required sources:
   - Prototype HTML files under `.../SwiftUIFeatures/prototypes`.
   - Speckit docs (`specify` + `tasks` minimum; use `analyze/plan` for ambiguity).
   - Current UIKit target files.
2. Build per-screen requirement matrix directly from prototype:
   - Sections and field order.
   - Card structure and spacing rhythm.
   - Button hierarchy and control styles.
   - Popover/list interactions and selected states.
3. Produce per-screen gap analysis:
   - Mark each item as `implemented`, `partial`, or `missing`.
   - Prioritize layout/safe-area issues before visual polish.
4. Implement in smallest safe increments:
   - First pass: structural layout and constraints.
   - Second pass: style tokens/helpers to reduce code noise.
   - Third pass: interaction parity (selection, long-press, context-specific states).
5. Validate each pass:
   - Run file-level error checks on touched files.
   - Re-check critical flows that changed notification/selection state.
6. Report:
   - What changed per screen.
   - Remaining gaps (if any).
   - Next patch options.

## Common Pitfalls
- Treating storyboard geometry as final layout for complex redesigns.
- Styling parity without state parity (selected row, disabled/read-only fields, expansion states).
- Partial popover parity (search frame/chips/row highlight not aligned with prototype intent).
- Introducing style helpers without ensuring compile visibility in every target file.

## Validation Checklist
- [ ] Field order and section grouping match prototype intent.
- [ ] Screen content stays within safe area on multiple simulator sizes.
- [ ] Buttons and cards use consistent style baselines.
- [ ] Popover list selection behavior matches expected flow.
- [ ] Read-only/update-state visuals are distinguishable and consistent.
- [ ] No backend/data contract changes were introduced.
- [ ] Touched files pass file-level error checks.
