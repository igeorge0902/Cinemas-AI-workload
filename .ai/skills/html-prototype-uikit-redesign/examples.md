# Examples: HTML Prototype to UIKit Redesign

## Example 1: AdminVC/AdminUpdateVC from Prototype
### Input
Apply `adminvc-adminupdate-redesign.prototype.html` from `/Users/gyorgy.gaspar/work/cinemas/cinemas/.ai/workflows/features/SwiftUIFeatures/prototypes` and fix safe-area clipping in `AdminVC` and `AdminUpdateVC`.

### Output
- Reads prototype + Speckit docs (`analyze`, `plan`, `specify`, `tasks`).
- Builds requirement matrix from HTML:
  - Card sections and visual hierarchy.
  - Field order and read-only vs editable states.
  - Selector button behavior and popover entry points.
- Replaces unstable storyboard geometry with programmatic scroll/card layout.
- Removes stale storyboard subviews before rebuilding content stack.
- Keeps notification names, segue IDs, and DataManager payload paths unchanged.
- Validates touched files with file-level error checks.

## Example 2: Movie/Venue Popover Parity
### Input
Align selector popovers to prototype intent for `MoviesVC` and `VenuesVC`.

### Output
- Adds bordered popover search surface and compact row styling.
- Uses selected-row gray highlight on full row area.
- Keeps venue capacity bubble aligned at row right side.
- Supports long-press expansion in venue list without breaking collapsed baseline height.
- Refactors repeated style literals into local style tokens/helpers to reduce code noise.

## Example 3: Menu/Purchases/Tickets Admin Style
### Input
Align `menuvc-purchasesvc-ticketsvc-adminstyle.prototype.html` interactions for `MenuVC`, `PurchasesVC`, and `TicketsVC` without API changes.

### Output
- Confirms refund/delete/PDF interaction expectations from Speckit docs.
- Implements UI/interaction changes only in UIKit files.
- Keeps payload keys, notification names, and segue IDs unchanged.
- Returns a concise parity report and follow-up patch options.
