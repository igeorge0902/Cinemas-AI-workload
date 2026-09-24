# UIKit Draft Notes: MenuVC + PurchasesVC + TicketsVC (Pre-implementation)

This file is a draft-only companion for review. It does not change runtime code.

## Intent
- Implement new design only.
- Keep existing behavior intact.
- Reuse CustomCells/shared list/button patterns.

## Draft interaction notes

### Purchases long-press + swipe state machine (draft)
```swift
// Draft idea only
enum PurchaseRowState {
    case idle
    case swipeEnabled
    case armedForRefund
}
```

```swift
// Draft idea only
func handlePurchaseLongPress(_ gesture: UILongPressGestureRecognizer) {
    // 1) enable swipe
    // 2) first swipe arms refund
    // 3) second swipe confirms refund
}
```

### Refund overlay bubble model (draft)
```swift
// Draft idea only
struct RefundedEntry {
    let purchaseId: String
    let movieName: String
}

final class RefundOverlayView: UIView {
    func update(entries: [RefundedEntry]) {
        // Render cumulative gray, non-blocking overlay text
    }
}
```

### Tickets PDF flow alignment (draft)
```swift
// Draft idea only
func openPdfPreview() {
    // Use existing TicketsVC Pdf action flow
    // Share action available in PDF view state
}
```

## Reusable direction
- Prefer `ListViewCell` and `FeedCells` patterns for row composition.
- Keep shared constraint setup via `UIViewExt.addConstraintswithFormat` patterns.
- Keep all DataManager/BackendServices calls unchanged.

## Guardrails checklist
- [ ] No new endpoints/functions
- [ ] No route/payload/notification contract changes
- [ ] Purchases list remains scrollable + bottom-near layout
- [ ] Gray cumulative refund bubble remains non-blocking

