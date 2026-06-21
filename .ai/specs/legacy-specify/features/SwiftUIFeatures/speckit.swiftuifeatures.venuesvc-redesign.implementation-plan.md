# Implementation Plan - VenuesVC / VenuesMigration Redesign

## Source of truth
- Tasks: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesvc-redesign.tasks`
- Spec: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesvc-redesign.specify`
- Prototype: `/.ai/workflows/features/SwiftUIFeatures/prototypes/venuesvc-redesign.prototype.html`

## Exact view controllers / views
- UIKit VC: `SwiftCinemas/SwiftLoginScreen/VenuesVC.swift`
- SwiftUI migration surface: `SwiftCinemas/SwiftLoginScreen/VenuesMigration/VenuesMigration.swift`
  - `VenuesMigrationView`
  - `VenuesMigrationHostVC`

## Storyboard and navigation contracts to keep
- UIKit segue ID unchanged:
  - `goto_venues_details`
- Migration to details must keep storyboard ID usage:
  - `UIStoryboard(name: "Storyboard", bundle: nil)`
  - `instantiateViewController(withIdentifier: "VenuesDetailsVC")`
- Keep map/admin notification semantics unchanged:
  - `newScreenVenueSelected`
  - `screeningVenueSelected`

## Redesign scope (no behavior break)
1. One-row-per-venue vertical list style polish.
2. Bottom details panel with name/address only (no map embed).
3. Two-step flow:
   - row tap selects + updates details panel
   - bottom CTA triggers forward navigation
4. Implement parity in both UIKit and SwiftUI targets.

## Step-by-step coding plan
1. **UIKit `VenuesVC`**
   - Keep `UITableView` + data loading methods unchanged.
   - Stop immediate segue in `didSelectRowAt` for standard mode.
   - Add bottom CTA button in `detailsView`; enable after selection.
   - CTA triggers existing `goto_venues_details` segue.
2. **SwiftUI `VenuesMigrationView` standard mode**
   - Keep list selection behavior.
   - Keep bottom details panel.
   - Gate `View Details` CTA until row selected.
3. **Map/Admin parity constraints**
   - No redesign behavior change that breaks map/admin notification flows.
4. **Regression checks**
   - Verify both surfaces still open `VenuesDetailsVC` with same selected context.

## Review checklist
- [ ] UIKit first tap selects only; second tap CTA navigates.
- [ ] SwiftUI standard mode mirrors same two-step behavior.
- [ ] `goto_venues_details` and storyboard-based details presentation still work.
- [ ] No map embedding in bottom details panels.
- [ ] Admin/map flows remain intact.

