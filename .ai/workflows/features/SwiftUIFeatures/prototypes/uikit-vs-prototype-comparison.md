# UIKit vs Prototype + Speckit Comparison

This comparison is based on static review of:
- `adminvc-adminupdate-redesign.prototype.html`
- `menuvc-purchasesvc-ticketsvc-adminstyle.prototype.html`
- Speckit docs (`analyze/plan/specify/tasks/uikit-draft` for both feature groups)
- Current UIKit files: `AdminVC.swift`, `AdminUpdateVC.swift`, `MenuVC.swift`, `PurchasesVC.swift`, `TicketsVC.swift`

## Generated SVGs (current UIKit visual map)
- `current-admin.svg`
- `current-adminupdate.svg`
- `current-menu.svg`
- `current-purchases.svg`
- `current-tickets.svg`

## Screen-by-Screen Gap Summary

## Admin (`AdminVC`)
Expected:
- Section flow: Movie/Venue -> Screening Date -> Rows+Seats (same row) -> Screen ID -> Category.
- Admin-styled top/bottom actions.
- Popover alignment to prototype.

Current gaps:
- Storyboard still appears to be a risk area for exact section geometry/order fidelity versus prototype card grouping.
- Visual grouping in UIKit is functional but not yet 1:1 with prototype card boundaries/spacing.

## AdminUpdate (`AdminUpdateVC`)
Expected:
- Read-only gray movie/venue fields, changed venue neutral marker.
- Save/Delete bottom bar.
- Compact movie popover in update mode.

Current gaps:
- Prefill is driven by shared context variables and available in-memory list; if screening context is stale/missing, visual parity may degrade.
- Still not fully card-structured as in prototype HTML composition.

## Menu (`MenuVC`)
Expected:
- Card hierarchy with profile data + image + admin style actions.

Current gaps:
- Mostly aligned; minor typography/spacing/border-weight differences from prototype remain.

## Purchases (`PurchasesVC`)
Expected:
- Long-press -> swipe refund flow with clear affordance.
- Non-blocking cumulative refund bubble.
- Admin-styled sort controls.

Current gaps:
- Affordance clarity can still be improved to match prototype hinting and row decoration exactly.
- Row visual polish (badges/spacing/line hierarchy) is close but not exact prototype parity.

## Tickets (`TicketsVC`)
Expected:
- Long-press reveal delete affordance.
- Ticket card readability (poster + QR + metadata).
- PDF preview with share/close flow.

Current gaps:
- Delete reveal interaction style differs from prototype's explicit secondary reveal row semantics.
- Card spacing/typography and reveal affordance visuals are not yet exact parity.

## Speckit-Correctness Checklist (high priority)
- [ ] Admin/AdminUpdate: finalize exact form section spacing and order parity from prototype cards.
- [ ] AdminUpdate: harden prefill source path so selected screening context always resolves predictably.
- [ ] Purchases: strengthen visible long-press/swipe guidance and row-level cue consistency.
- [ ] Tickets: shift to stricter reveal-row interaction pattern for delete action.
- [ ] Cross-screen: normalize typography, spacing, border, and chip/badge visuals to prototype baselines.

## Relevant source files
- Prototypes:
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/.ai/workflows/features/SwiftUIFeatures/prototypes/adminvc-adminupdate-redesign.prototype.html`
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/.ai/workflows/features/SwiftUIFeatures/prototypes/menuvc-purchasesvc-ticketsvc-adminstyle.prototype.html`
- UIKit:
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/SwiftCinemas/SwiftLoginScreen/AdminVC.swift`
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift`
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/SwiftCinemas/SwiftLoginScreen/MenuVC.swift`
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift`
  - `/Users/gyorgy.gaspar/work/cinemas/cinemas/SwiftCinemas/SwiftLoginScreen/TicketsVC.swift`

