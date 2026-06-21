# Speckit Analyze: MenuVC + PurchasesVC + TicketsVC admin-style alignment

## Objective
Align `MenuVC`, `PurchasesVC`, and `TicketsVC` to the approved admin-style redesign while preserving existing runtime contracts.

Additional focus for this pass:
- Menu profile page should explicitly represent backend-driven profile image loading.
- Tickets UI must clearly show ticket data + QR content.
- Ticket row delete affordance should be long-press-revealed.
- When the last ticket is deleted, UI should indicate purchase deletion and navigate back to `PurchasesVC`.

## Current code findings

### 0) Purchases row interaction should communicate swipe intent more clearly
- Refund in `PurchasesVC` is implemented as a trailing swipe row action, not a persistent visible button.
- Current redesign artifacts should avoid implying a standalone details CTA and instead explain swipe-left affordance.
- Movie images are already present in `cellForRowAt` and should be visually explicit in redesign rows.
- References:
  - `SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift:153-197`
  - `SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift:217-249`
- Gap:
  - Add explicit swipe guidance and movie-thumbnail prominence in Purchases artifacts.

### 1) MenuVC already pulls profile + image from backend
- `MenuVC` fetches profile data via `AuthDataManager.shared.fetchUserProfile()`.
- It binds username/email and loads `profilePicture` through image service caching.
- References:
  - `SwiftCinemas/SwiftLoginScreen/MenuVC.swift:111-154`
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/AuthDataManager.swift:68-75`
- Gap:
  - UI currently behaves like a single menu screen with embedded profile widgets; redesign should treat this as a clearer profile section/page state.

### 2) TicketsVC already renders ticket data and QR
- Tickets are fetched by selected purchase and sorted by seat number.
- Ticket cells show movie/ticket metadata and render QR via `CIQRCodeGenerator` from seat number.
- References:
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:197-212`
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:296-327`
- Gap:
  - Current redesign artifacts should explicitly communicate QR + data prominence in a card/list hierarchy.

### 3) Long-press delete affordance is not implemented in UIKit code
- Current delete affordance is an always-visible trash icon button on each ticket cell.
- No long-press gesture path currently reveals delete controls.
- References:
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:306-311`
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:217-237`
- Gap:
  - New UX requires long press to reveal a delete line/icon below the ticket row.

### 4) Last-ticket deletion state does not currently navigate back
- `cancelTicket` removes the local row and reloads collection.
- There is no explicit empty-state toast/banner saying purchase got deleted, and no auto-navigation back to purchases.
- References:
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:217-237`
  - `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift:243-248`
  - `SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift:211-215`
- Gap:
  - UX addition required: show purchase-deleted confirmation and route back to `PurchasesVC` when no tickets remain.

### 5) DataManager/backend contracts should remain unchanged
- Ticket retrieval/cancel and purchase retrieval/refund contracts already exist and should be reused.
- References:
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/CheckoutDataManager.swift:27-108`
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/CheckoutDataManager.swift:174-197`
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/CheckoutDataManager.swift:207-239`
- Gap:
  - Changes are UI-state/interaction oriented; no endpoint additions required in this redesign pass.

### 6) Reusable list cell/button track should leverage existing CustomCells
- Existing reusable patterns already exist and can be reused for this feature:
  - `ListViewCell` for list-row composition and consistent rounded-card styling.
  - `FeedCells` for mixed media + detail composition patterns.
  - `UIViewExt.addConstraintswithFormat` for shared layout constraint setup.
- References:
  - `SwiftCinemas/SwiftLoginScreen/ListViewCell.swift`
  - `SwiftCinemas/SwiftLoginScreen/FeedCells.swift`
  - `SwiftCinemas/SwiftLoginScreen/UIViewExt.swift`
- Gap:
  - Current VCs still contain screen-local view setup and button styling. A reusable component side-track should be included as a deliverable to reduce duplication.

## Recommended implementation scope

### Must-do
1. Clarify Purchases swipe-to-refund UX in row-level affordance copy/state.
2. Keep movie picture visible in Purchases rows.
3. Remove unnecessary Purchases `Details` button from redesign artifacts.
4. Promote Menu profile section as an explicit profile page state and keep backend image/fallback behavior obvious.
5. Keep Tickets card rows showing QR and ticket metadata clearly.
6. Add long-press-to-reveal delete row affordance for ticket rows.
7. Add final-ticket-deleted UX chain:
   - show success message (purchase deleted)
   - navigate back to `PurchasesVC`
8. Keep all DataManager and backend service contracts unchanged.
9. Add reusable list-cell and button component implementation as a side deliverable, reusing existing CustomCells patterns.

### Should-do
1. Add light haptic feedback on long-press reveal for affordance confirmation.
2. Add an in-view transient banner for purchase-deleted state before auto-navigation.
3. Extract repeated row/button styling into shared reusable components first, then wire the three VCs to consume them.

## Implementation files
- `SwiftCinemas/SwiftLoginScreen/MenuVC.swift`
- `SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift`
- `SwiftCinemas/SwiftLoginScreen/DataManagers/AuthDataManager.swift`
- `SwiftCinemas/SwiftLoginScreen/DataManagers/CheckoutDataManager.swift`
- `SwiftCinemas/SwiftLoginScreen/ListViewCell.swift`
- `SwiftCinemas/SwiftLoginScreen/FeedCells.swift`
- `SwiftCinemas/SwiftLoginScreen/UIViewExt.swift`
- `.ai/workflows/features/SwiftUIFeatures/prototypes/menuvc-purchasesvc-ticketsvc-adminstyle.prototype.html`
- `SwiftCinemas/SwiftLoginScreen/menu-screen.svg`
- `SwiftCinemas/SwiftLoginScreen/purchases-screen.svg`
- `SwiftCinemas/SwiftLoginScreen/tickets-screen.svg`

## Out of scope
- New backend endpoints
- Payload key contract changes
- Auth/header transport changes

