# SwiftUIFeatures Redesign - Implementation Runbook

Date: 2026-05-09
Owner: `@ios-dev`
Manual verification owner: `@user`
Execution mode: Screen-by-screen replacement with compile gate after each chunk
Current active implementation target: Final batch closeout + pending user manual handoffs

## Source task artifacts
- `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.tasks`
- `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesvc-redesign.tasks`
- `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venueformoviesvc-redesign.tasks`
- `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesdetailsvc-redesign.tasks`
- `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.redesign-ios-dev.execution-plan.md`

## Global execution rules
- Replace code one screen at a time only.
- After each replacement chunk, run compile check and fix build issues before continuing.
- Do not start the next screen until current screen compiles cleanly.
- Manual verification is user-owned and runs after compile-clean handoff.

## Compile gate command template
Use your local workspace/scheme values.

```bash
xcodebuild -workspace "<YourWorkspace>.xcworkspace" -scheme "<YourScheme>" -configuration Debug -destination "generic/platform=iOS" build
```

---

## Screen 1 - `MoviesVC` (`moviesvc-redesign`)
Task file: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.tasks`

### Implementation checklist (`@ios-dev`)
- [ ] Phase 1A compile-gate mode active for `MoviesVC`.
- [ ] Phase 2 UI structure redesign complete.
- [ ] Phase 3 categories source + fallback complete.
- [ ] Phase 4 favorites complete.
- [ ] Phase 5 ratings fixture + fallback complete.
- [ ] Phase 6 footer removal complete.
- [ ] Phase 7 error handling/diagnostics complete.
- [ ] Phase 8 prototype alignment complete.
- [ ] Phase 10 deferred safety backlog tracked (`RISK-MVC-SAFE-001`) and unchanged unless explicitly in scope.

### Compile checkpoints (`@ios-dev`)
- [ ] Compile after Phase 2
- [ ] Compile after Phase 3
- [ ] Compile after Phase 5
- [ ] Compile after Phase 7
- [ ] Final compile before handoff

### Manual verification handoff (`@user`)
- [ ] Run Phase 9 manual verification list from task file.

---

## Screen 2 - `VenuesVC` + `VenuesMigration` parity (`venuesvc-redesign`)
Task file: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesvc-redesign.tasks`

### Implementation checklist (`@ios-dev`)
- [x] Phase 1A compile-gate mode active for `VenuesVC`/`VenuesMigration`.
- [x] Phase 2 UIKit list redesign complete.
- [x] Phase 2B SwiftUI migration parity complete.
- [x] Phase 3 selection details panel complete.
- [x] Phase 4 contract/navigation preservation complete.
- [x] Phase 5 stability/performance complete.

### Compile checkpoints (`@ios-dev`)
- [ ] Compile after Phase 2
- [ ] Compile after Phase 2B
- [ ] Compile after Phase 3
- [ ] Compile after Phase 5
- [x] Final compile before handoff

### Manual verification handoff (`@user`)
- [ ] Run Phase 6 manual verification list from task file.

---

## Screen 3 - `VenueForMoviesVC` (`venueformoviesvc-redesign`)
Task file: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venueformoviesvc-redesign.tasks`

### Implementation checklist (`@ios-dev`)
- [x] Phase 1A compile-gate mode active for `VenueForMoviesVC`.
- [x] Phase 2 list polish complete.
- [x] Phase 3 metadata wiring + fallback labels complete.
- [x] Phase 4 contract/flow preservation complete.
- [x] Phase 5 stability/performance complete.

### Compile checkpoints (`@ios-dev`)
- [ ] Compile after Phase 2
- [ ] Compile after Phase 3
- [ ] Compile after Phase 5
- [x] Final compile before handoff

### Manual verification handoff (`@user`)
- [ ] Run Phase 6 manual verification list from task file.

---

## Screen 4 - `VenuesDetailsVC` (`venuesdetailsvc-redesign`)
Task file: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesdetailsvc-redesign.tasks`

### Implementation checklist (`@ios-dev`)
- [x] Phase 1A compile-gate mode active for `VenuesDetailsVC`.
- [x] Phase 2 layout refactor complete.
- [x] Phase 3 action contract preservation complete.
- [x] Phase 4 stability/performance complete.

### Compile checkpoints (`@ios-dev`)
- [ ] Compile after Phase 2
- [ ] Compile after Phase 3
- [ ] Compile after Phase 4
- [x] Final compile before handoff

### Manual verification handoff (`@user`)
- [x] Run Phase 5 manual verification list from task file.

---

## Final batch closeout
- [ ] Cross-feature compile check passes after all four screens.
- [ ] Deferred backlog items remain tracked (no silent scope creep).
- [ ] User manual verification completed for each screen handoff.
- [ ] Any discovered issues are appended back to the respective `*.tasks` file.

