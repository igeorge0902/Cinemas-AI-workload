# Review / Analyze - Recent DataManager Migration

Date: 2026-05-09
Scope: Recent Swift DataManager migration implementation and its current verification state.

## Findings (ordered by severity)

### 1) Note - User confirmed runtime uses a different backend endpoint for this flow
- User clarification: map -> venue-movies -> venue-details is working correctly in the current environment.
- Action: treat prior venue/movie pairing concern as not applicable for current runtime endpoint until a reproducible mismatch is observed in this environment.
- Keep this as a deferred watchpoint only if future payload mapping issues appear.

### 2) Note - No-guard behavior is intentional in `VenueForMoviesVC` and accepted by flow policy
- File: `SwiftCinemas/SwiftLoginScreen/VenueForMoviesVC.swift:28-43`
- You explicitly confirmed the no-guard approach is intentional: with no data, navigation should not be possible.
- Review updated accordingly: this is treated as design choice, not an actionable migration defect.

### 3) Medium - Migration verification gates are still open
- File: `.ai/workflows/features/Swift_migration/speckit.swiftui.swift-migration-data-managers.tasks:258-281, 297-319, 328-349`
- Deferred checks include auth/payment integration, full Appium E2E, performance profiling, and sign-off tasks.
- Risk: migration is functionally advanced but still under-verified for regressions in end-to-end scenarios.
- Recommended fix:
  - Run at least one mandatory reduced verification pack before marking migration fully closed:
    - Auth + checkout integration
    - Movies -> Venues -> VenueDetails smoke
    - Dates -> Seats -> Basket smoke

## Additional observations
- `VenuesVC` and `VenuesMigration` both preserve selection context propagation patterns and remain aligned with manager-based flow entry points.
- `VenuesDetailsVC` already includes one-time setup guards (`hasSetupUI`, `hasInitializedPlayer`) that reduce migration-related lifecycle churn.

## Suggested short verification pack (before redesign implementation)
1. `MoviesVC` select movie -> `VenuesVC`/`VenuesMigration` selection flow validates selected manager context.
2. `VenueForMoviesVC` select row -> `goto_venues_details2` passes correct movie + venue + location.
3. `VenuesDetailsVC` date selection -> seats popover opens and selected date context remains stable.
4. Checkout smoke: selected seats persist into basket payload and payment call path.

## Conclusion
The migration is in good shape for redesign work, but the venue/movie pairing heuristic in `VenuesDataManager.fetchVenueMovieSelections()` is a concrete correctness risk and should be addressed first. Defensive selection guards in `VenueForMoviesVC` are also recommended before UI redesign changes are layered on top.

