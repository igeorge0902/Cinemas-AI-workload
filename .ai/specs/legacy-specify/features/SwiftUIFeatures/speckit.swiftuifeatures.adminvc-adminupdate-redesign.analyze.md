# Speckit Analyze: AdminVC + AdminUpdateVC redesign alignment

## Objective
Align iOS implementation with the approved admin prototypes:
- screening date above capacity fields
- rows/seats side-by-side
- category optional
- stronger admin visual grouping
- popover list style aligned to admin usage (movie posters in admin create, compact `venue > movie` rows in admin update)
- movie selector rows should not expose internal movie IDs in the visible prototype state
- AdminUpdateVC fields should be prefilled from the backend screening context before editing starts

## Implementation guardrails (UIKit)
- UIKit implementation only for this pass.
- Scope is design alignment only (layout/style/interaction cues), not feature expansion.
- Keep all existing admin features, routes, notifications, payload keys, and service usage intact.
- Reuse existing shared/reusable building blocks (cells/lists/buttons/helpers) wherever possible before introducing screen-local one-offs.

## Current code findings

### 1) AdminVC layout order and sizing mismatch
- `Storyboard.storyboard` currently places:
  - `NrOfRows` at y=174 and `NrOfSeats` at y=248 (stacked vertically)
  - `Screening Date` at y=322 (below capacity fields)
- References:
  - `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard:259-288`
- Required by design:
  - move `Screening Date` above capacity
  - place rows + seats on the same horizontal row

### 2) AdminVC capacity inputs are too narrow for new design
- `NrOfRows` and `NrOfSeats` text fields are fixed at ~51 px widths.
- References:
  - `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard:265-274`
- Required by design:
  - equal-width half-row fields in one horizontal group

### 3) AdminUpdateVC top and bottom actions are frame-based
- `AdminUpdateVC` uses hardcoded frame buttons in `viewWillAppear`:
  - top `Back` + `Clear`
  - bottom `Save` + `Delete`
- References:
  - `SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift:60-92`
- Required by design:
  - keep visual style consistent with shared top navigation button system and safe-area aligned placement

### 4) AdminVC bottom Save action is frame-based
- `AdminVC` top uses shared helper, but Save button is still manually framed.
- References:
  - `SwiftCinemas/SwiftLoginScreen/AdminVC.swift:61-74`
- Required by design:
  - stable bottom action placement and consistent style behavior

### 5) Category already optional in logic, but UI semantics need explicit alignment
- Validation already allows empty category by checking only non-empty invalid values.
- References:
  - `SwiftCinemas/SwiftLoginScreen/AdminVC.swift:209-217`
  - `SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift:233-242`
- Required by design:
  - label and task semantics should mark category as optional (no blocking behavior)

### 6) Popover behavior exists but styling/grouping needs polish for admin look
- Admin flows already present `MoviesVC`/`VenuesVC` as popovers (90% width, 50% height, no arrow).
- References:
  - `SwiftCinemas/SwiftLoginScreen/AdminVC.swift:128-179`
  - `SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift:146-198`
- Movie list behavior by mode:
  - admin create path can show movie imagery
  - admin update path uses compact `venue > movie` rows
- References:
  - `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift` (admin mode cell paths)
- Venue list behavior:
  - admin list mode with selected-item emphasis
- References:
  - `SwiftCinemas/SwiftLoginScreen/VenuesVC.swift` (admin list rendering path)

### 7) Movie selector prototype exposes internal movie IDs unnecessarily
- The prototype currently renders movie tags like `id:12`, `id:7`, `id:18` in the admin create movie list, and compact update rows also show IDs.
- References:
  - `.ai/workflows/features/SwiftUIFeatures/prototypes/adminvc-adminupdate-redesign.prototype.html:252-276`
  - `.ai/workflows/features/SwiftUIFeatures/prototypes/adminvc-adminupdate-redesign.prototype.html:327-333`
- Required by design:
  - show poster + title only in the create-mode movie list
  - show compact venue/movie text without ID tags in update mode

### 8) AdminUpdateVC should load existing screening values from the backend context
- Existing data is already available through `AdminDataManager.fetchScreenings(category:)`, which calls:
  - `mbooks.adminMoviesOnVenues()`
  - `mbooks.adminMoviesOnVenuesCategorized(query:)`
  - `mbooks.adminMoviesOnVenuesSearch(query:)`
- Returned `AdminScreeningModel` items include movie, movieId, date, venue, venueId, screeningId, category, and screeningDatesId.
- `resolveScreenContext()` already prefers the currently selected in-memory screening context and falls back to selected `AdminScreeningModel` values.
- References:
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/AdminScreeningsDataManager.swift:28-49`
  - `SwiftCinemas/SwiftLoginScreen/DataManagers/AdminScreeningsDataManager.swift:141-166`
  - `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift:106-116`
- Required by design:
  - prefill all update-screen inputs from the selected backend screening record before the user edits anything
  - keep the backend fetch path unchanged; this is a UI binding/prefill requirement, not an endpoint change

### 9) Changed venue state should not rely on red font styling
- The update screen currently uses red emphasis for the selected/changed venue state in the prototype.
- Required by design:
  - indicate a changed venue with a neutral parenthetical marker such as `(changed)`
  - keep normal text color and use spacing/badge treatment instead of destructive/error coloring

### 10) AdminUpdateVC movie and venue values should appear locked/grayed out
- The update screen should show movie and venue as grayed-out selection values, not as freely editable white text fields.
- Required by design:
  - keep the Select buttons and popover lists as the only change path for movie/venue
  - preserve the read-only visual treatment so the fields read as locked selections even when values are prefilled from backend data

### 11) Reusable cell/button track should reuse existing CustomCells patterns
- Admin redesign should include a side-track for reusable row/button components rather than one-off per-screen styling.
- Existing reusable iOS patterns should be leveraged first:
  - `ListViewCell` for list row composition and visual consistency
  - `FeedCells` for mixed media + metadata row patterns
  - `UIViewExt.addConstraintswithFormat` for consistent layout helpers
- Gap:
  - Admin screens currently rely on local frame/layout styling; reusable component extraction should be part of implementation deliverables.

### 7) Storyboard maintenance risk in AdminUpdateVC
- Heavy `fixedFrame` usage limits adaptability across devices and conflicts with redesigned grouped layout.
- References:
  - `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard:445-573`

## Recommended implementation scope

### Must-do
1. Rework AdminVC form order + constraints in storyboard:
   - `Movie/Venue` block
   - `Screening Date`
   - `Rows + Seats` one row
   - `Screen ID + Category`
2. Replace hardcoded action button frames with constraint-based layout in both admin screens.
3. Preserve existing payload keys and segue/action wiring.
4. Keep category optional and update labels/help text to reflect it.
5. Align popover styling in Movies/Venues selection to admin visual language while preserving data behavior.
6. Remove movie IDs from the visible movie selector UI.
7. Prefill AdminUpdateVC fields from the backend-provided screening context.
8. Replace red venue-change emphasis with a parenthetical indicator.
9. Keep AdminUpdateVC movie and venue fields grayed out as locked selections.
10. Add reusable list-cell/button component side-deliverable reusing existing CustomCells patterns.

### Should-do
1. Add reusable section container styling helper for admin cards.
2. Add consistent typography spacing for field groups and section headers.
3. Ensure touch targets remain >=44pt.
4. Unify admin row/button visuals by reusing shared cell/button building blocks before screen-level tweaks.

## Implementation files
- `SwiftCinemas/SwiftLoginScreen/AdminVC.swift`
- `SwiftCinemas/SwiftLoginScreen/AdminUpdateVC.swift`
- `SwiftCinemas/SwiftLoginScreen/Storyboard.storyboard`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/VenuesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/ListViewCell.swift`
- `SwiftCinemas/SwiftLoginScreen/FeedCells.swift`
- `SwiftCinemas/SwiftLoginScreen/UIViewExt.swift`

## Out of scope
- backend endpoint contracts
- payload key renaming
- auth/header contracts
- business logic changes in create/update/delete flows

