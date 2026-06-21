# iOS Dev Execution Plan - SwiftUIFeatures Redesign Set

Date: 2026-05-09
Owner: `@ios-dev`
Scope: planning/execution for
- `moviesvc-redesign`
- `venueformoviesvc-redesign`
- `venuesvc-redesign`
- `venuesdetailsvc-redesign`

## Final conclusion

- Backend remains the baseline contract.
- Do not introduce new backend endpoints for this redesign batch.
- Where backend responses do not provide fields used in visual prototypes (for example: `rating`, `category`), use iOS-side static fallback text/data.
- Keep all existing navigation and payload/header contracts unchanged.
- Delivery is UIKit-first, with `VenuesMigration` parity where already required by existing feature docs.

## Delivery sequence (dependency-aware)

1. `moviesvc-redesign` (source list + categories + ratings + favorites)
2. `venuesvc-redesign` (venue selection flow and details panel)
3. `venueformoviesvc-redesign` (list enrichment: category/date)
4. `venuesdetailsvc-redesign` (hero/blur/actions polish)
5. Cross-feature regression pass (navigation, data handoff, visual parity)

## Execution policy (screen-by-screen)

- Replace code one screen at a time in the sequence above.
- After each replacement chunk, run compile check and fix errors before continuing.
- Do not start the next screen until the current screen compiles cleanly.
- Manual verification is user-owned and runs after compile-clean handoff for each screen.

## Sprint-style rollout checklist

### Wave 1 - MoviesVC foundation (2-3 days)
- [ ] Remove segmented control and replace with horizontal category chips.
- [ ] Use backend category values when available; fallback to static chips when missing.
- [ ] Bind ratings from static fixture; fallback `N/A` for missing mapping.
- [ ] Keep search bar behavior unchanged.
- [ ] Add local favorites toggle state.
- [ ] Remove footer visuals from MoviesVC only.

### Wave 2 - Venues selection flow (2 days)
- [ ] Apply expanded-list UI polish in `VenuesVC`.
- [ ] Keep two-step flow: row select first, bottom CTA navigate second.
- [ ] Keep bottom panel text-only (name + address), no embedded map.
- [ ] Maintain navigation contracts (`goto_venues_details`, map/admin flow semantics).
- [ ] Apply parity updates to `VenuesMigration` where feature docs require.

### Wave 3 - VenueForMovies + VenueDetails polish (2-3 days)
- [ ] `VenueForMoviesVC`: display `category` and `screeningDate` with static fallback labels.
- [ ] `VenueForMoviesVC`: keep one-row-per-item vertical list and existing navigation semantics.
- [ ] `VenuesDetailsVC`: rectangular hero media + scroll-driven blur.
- [ ] `VenuesDetailsVC`: details-first ordering, then vertical action buttons.
- [ ] Keep all existing selectors/segues/popovers unchanged.

### Wave 4 - Stability and regression (1-2 days)
- [ ] Verify no duplicate subview setup on repeated open/close cycles.
- [ ] Verify cell reuse safety for async image/metadata updates.
- [ ] Verify migration flag branch and classic UIKit branch both work.
- [ ] Verify fallback labels/text for all missing fields.
- [ ] Verify no sensitive logs and no contract/header changes.

## Per-artifact planning map

### moviesvc-redesign artifacts
- `speckit.swiftuifeatures.moviesvc-redesign.specify`
  - enforce backend-first + static fallback for `category` and `rating` display data
- `speckit.swiftuifeatures.moviesvc-redesign.plan`
  - iOS-only implementation path, no new mbooks endpoint work
- `speckit.swiftuifeatures.moviesvc-redesign.draft-code.md`
  - fallback-first helpers for categories and ratings
- `speckit.swiftuifeatures.moviesvc-redesign.implementation-plan.md`
  - keep storyboard and segue contracts unchanged
- `speckit.swiftuifeatures.moviesvc-redesign.tasks`
  - phases aligned to iOS-only delivery and verification

### venueformoviesvc-redesign artifacts
- `speckit.swiftuifeatures.venueformoviesvc-redesign.specify`
  - keep backend contract unchanged; fallback labels mandatory
- `speckit.swiftuifeatures.venueformoviesvc-redesign.plan`
  - expanded-list visual polish with preserved navigation semantics
- `speckit.swiftuifeatures.venueformoviesvc-redesign.draft-code.md`
  - row DTO/mapping with fallback fields
- `speckit.swiftuifeatures.venueformoviesvc-redesign.implementation-plan.md`
  - lifecycle/reuse safety and scroll smoothness checks
- `speckit.swiftuifeatures.venueformoviesvc-redesign.tasks`
  - six-phase iOS execution path already aligned

### venuesvc-redesign artifacts
- `speckit.swiftuifeatures.venuesvc-redesign.specify`
  - enforce UIKit + SwiftUI migration parity where required
- `speckit.swiftuifeatures.venuesvc-redesign.plan`
  - lock two-step selection + bottom CTA behavior
- `speckit.swiftuifeatures.venuesvc-redesign.draft-code.md`
  - safe selection-state handling and CTA enablement flow
- `speckit.swiftuifeatures.venuesvc-redesign.implementation-plan.md`
  - preserve segue and notification contracts
- `speckit.swiftuifeatures.venuesvc-redesign.tasks`
  - execute UIKit first, then migration parity pass

### venuesdetailsvc-redesign artifacts
- `speckit.swiftuifeatures.venuesdetailsvc-redesign.specify`
  - scroll/blur behavior with existing contracts preserved
- `speckit.swiftuifeatures.venuesdetailsvc-redesign.plan`
  - visual hierarchy lock: media -> text -> vertical actions
- `speckit.swiftuifeatures.venuesdetailsvc-redesign.draft-code.md`
  - clamped blur mapping and one-time setup guards
- `speckit.swiftuifeatures.venuesdetailsvc-redesign.implementation-plan.md`
  - selector and popover compatibility retained
- `speckit.swiftuifeatures.venuesdetailsvc-redesign.tasks`
  - stability checks before final manual verification

## Definition of done (redesign batch)

- [ ] No backend contract changes introduced.
- [ ] Static fallback coverage exists for missing prototype fields (`rating`, `category`, date fallback labels).
- [ ] All listed feature task files are actionable and phase-aligned.
- [ ] Navigation/segue/popover contracts are preserved.
- [ ] UIKit behavior remains stable across repeated open/close/use cycles.
- [ ] Required migration parity (`VenuesMigration`) validated where documented.

## Deferred fix-later items (tracked)

- [ ] `MoviesVC` category safety hardening: remove `category_!` force-unwrap paths that can crash before a category is selected in section 1 (primary repro at `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:254`).

