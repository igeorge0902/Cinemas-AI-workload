# Implementation Plan - VenueForMoviesVC Redesign (UIKit)

## Source of truth
- Tasks: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venueformoviesvc-redesign.tasks`
- Spec: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venueformoviesvc-redesign.specify`
- Prototype: `/.ai/workflows/features/SwiftUIFeatures/prototypes/venueformoviesvc-redesign.prototype.html`

## Exact view controllers / classes
- Primary VC: `SwiftCinemas/SwiftLoginScreen/VenueForMoviesVC.swift`
- Current cell: `SwiftCinemas/SwiftLoginScreen/MovieCollectionViewCell.swift`

## Storyboard and navigation contracts to keep
- Keep segue ID unchanged:
  - `goto_venues_details2`
- Keep `prepare(for:sender:)` data handoff unchanged:
  - `MoviesDataManager.shared.selectedMovie`
  - `VenuesDataManager.shared.selectedVenue`
  - `LocationsDataManager.shared.selectedLocationId`
- Keep back action behavior unchanged (`navigateBack`).

## Redesign scope (no behavior break)
1. Convert 2-column collection layout to expanded-list-like single-column rows.
2. Keep screen scrollable and touch friendly.
3. Add per-row metadata: movie category + screening date.
4. Populate metadata from existing endpoint payloads only.
5. Keep existing selection -> segue flow unchanged.

## Data notes
- Category: expected from movies endpoint data used by venue-movies response mapping.
- Screening date: expected from screening date endpoint mapping.
- No backend changes in this feature.

## Step-by-step coding plan
1. **Layout migration in same VC**
   - Keep `UICollectionView`, switch flow layout to one item per row (full width).
2. **Cell redesign support**
   - Extend `MovieCollectionViewCell` with labels:
     - `categoryLabel`
     - `screeningDateLabel`
3. **View model mapping in VC**
   - Introduce internal display DTO with fallback values:
     - `Category: N/A`
     - `Date: TBA`
4. **Cell configuration**
   - Bind title/image/category/date in `cellForItemAt`.
5. **Preserve navigation contract**
   - Keep `didSelectItemAt` calling same segue.
6. **Regression checks**
   - Verify Home -> Venues -> MapView -> VenueForMovies path unchanged.

## Review checklist
- [ ] `goto_venues_details2` still works.
- [ ] Back button still dismisses.
- [ ] List is single-column and scrollable.
- [ ] Category/date appear with fallbacks.
- [ ] No backend work required.

