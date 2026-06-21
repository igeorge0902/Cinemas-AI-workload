# Implementation Plan - MoviesVC Redesign (UIKit)

## Source of truth
- Tasks: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.tasks`
- Spec: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.specify`
- Prototype: `/.ai/workflows/features/SwiftUIFeatures/prototypes/movies-redesign2.prototype.html`

## Exact view controllers / classes
- Primary VC: `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift`
- Primary row cell: `SwiftCinemas/SwiftLoginScreen/ListViewCell.swift`
- Optional shared styling references: `SwiftCinemas/SwiftLoginScreen/MovieCollectionViewCell.swift` (`TrendingListCell`, `TrendingCarouselCell`)

## Storyboard and navigation contracts to keep
- Keep segue IDs unchanged:
  - `goto_venues`
  - `goto_movie_detail`
- Keep search and selection flows intact:
  - `prepare(for:sender:)` data handoff to `MoviesDataManager.shared.selectedMovie`
- Keep migration switch behavior intact:
  - `VenuesFeatureFlags.shouldUseMigration()` branch in `didSelectRowAt`

## Redesign scope (no behavior break)
1. Replace segmented control header UI with horizontal category chips UI.
2. Keep existing search bar active and visible.
3. Apply monochrome visual style only (no contract change).
4. Add favorite toggle visuals/state in rows.
5. Add mocked rating hydration from local fixture.
6. Remove footer/nav visuals inside MoviesVC only; do not remove functional navigation routes.

## Data and endpoint notes
- Category chips: derive from existing backend movie payload category fields when present; otherwise use static fallback chips.
- Ratings: local static fixture in app bundle (`ratings-mock.json`).
- Keep payload/header/session contracts unchanged.

## Step-by-step coding plan
1. **View structure prep in `MoviesVC`**
   - Introduce a reusable top stack container: title/search/chips.
   - Keep existing table and datasource contracts.
2. **Category chips presentation**
   - Replace segmented-control header (`viewForHeaderInSection`) with chips container.
   - Keep `section_`/category filtering semantics mapped to chip taps.
   - Build chip source with `backend categories -> fallback chips` precedence.
3. **Cell enhancement**
   - Extend `ListViewCell` with rating label + favorite button area.
   - Preserve compact/full layout modes used by admin/category rows.
4. **Favorites local state**
   - Add in-memory map keyed by movie ID in `MoviesVC`.
   - Wire favorite toggle callback without changing movie selection tap behavior.
5. **Ratings fixture**
   - Add decoding helper and load fixture once in `viewDidLoad`.
   - Map rating by movieId; fallback `N/A`.
6. **Error-safe fallback**
   - If backend categories are missing or fixture parse fails, list still renders with fallback chips/ratings.
7. **Regression checks**
   - Verify search, pagination, segue handoff, and migration branch still work.

## Review checklist
- [ ] `MoviesVC` still opens venues/details with same segue IDs.
- [ ] Search behavior unchanged.
- [ ] Category chips replace segmented control but preserve filter behavior.
- [ ] Favorite/rating UI is additive and non-blocking.
- [ ] No backend contract/header changes introduced.

## Risk Register (deferred)
- **RISK-MVC-SAFE-001** - `category_!` force-unwrap crash before first category selection in section 1.
  - Primary repro: `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:254`
  - Related paths: `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:527`, `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:531`, `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:590`, `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:603`
  - Severity: Critical (primary search path), High (related pagination/admin paths)
  - Status: Deferred (`FIX LATER`) for safety hardening backlog
  - Tracking:
    - `.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.tasks` (Phase 10)
    - `.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-safety.analyze.md`

