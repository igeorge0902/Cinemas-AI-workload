# Implementation Plan - VenuesDetailsVC Redesign (UIKit)

## Source of truth
- Tasks: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesdetailsvc-redesign.tasks`
- Spec: `/.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.venuesdetailsvc-redesign.specify`
- Prototype: `/.ai/workflows/features/SwiftUIFeatures/prototypes/venuesdetailsvc-redesign.prototype.html`

## Exact view controllers / classes
- Primary VC: `SwiftCinemas/SwiftLoginScreen/VenuesDetailsVC.swift`
- Popovers used by existing flows:
  - `PopOver` (seats)
  - `PopOverDates` (dates)
  - `iOSCalendarVC` (calendar)

## Storyboard and navigation contracts to keep
- Keep segue IDs unchanged:
  - `goto_map2`
  - `goto_movie_detail2`
- Keep selector targets unchanged:
  - `book`, `dates`, `map`, `movieDetail`, `selectCalendar`, `navigateBack`
- Keep payload contracts unchanged:
  - seat flow depends on selected screening date and existing checkout contracts

## Redesign scope (no behavior break)
1. Keep top hero media rectangular.
2. Add scroll-progress blur effect over hero area.
3. Reorder content so detail text appears before controls.
4. Present actions as vertical stack.
5. Keep back button visible.

## Step-by-step coding plan
1. **Structural wrappers**
   - Introduce hero container + blur overlay view.
   - Keep current image/video loading paths.
2. **Scroll-driven blur**
   - In `scrollViewDidScroll`, map offset to clamped blur alpha/value.
3. **Vertical action stack**
   - Replace two-row button layout with one vertical stack while preserving selectors.
4. **Text-first order**
   - Ensure `setupTextView()` appears before action stack in visual hierarchy.
5. **Stability**
   - Keep one-time guards (`hasSetupUI`, `hasInitializedPlayer`, `isLoadingSeats`).

## Review checklist
- [ ] `goto_map2` and `goto_movie_detail2` still work.
- [ ] Book/Dates/Calendar popovers still open and behave.
- [ ] Text appears before action buttons.
- [ ] Buttons are vertical and wired to same selectors.
- [ ] No contract changes in booking/date/payment flows.

