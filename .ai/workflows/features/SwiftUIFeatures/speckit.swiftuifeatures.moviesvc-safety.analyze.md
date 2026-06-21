# Analysis: MoviesVC category force-unwrap crash risk

Date: 2026-05-09
Owner: `@ios-dev`
Status: Deferred backlog item (`FIX LATER`)

## Scope

Focused analysis of category-search safety paths in:
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift`

## Findings

### Critical finding A (primary)
- Location: `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:254`
- Code path: search text change (`count > 2`) -> `section_ == 1` -> `addData_(searchText, category: self.category_!)`
- Risk: crash if `category_` is `nil`.
- Trigger scenario:
  1. Open Movies screen.
  2. Switch segmented control to Categories mode (`section_ = 1`).
  3. Type 3+ chars in search before selecting a category row.

### Related force-unwrap risk paths
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:527`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:531`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:590`
- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift:603`

## Root cause summary

`section_` can become `1` before `category_` gets a value.
- `category_` is optional and reset to nil on reset path.
- Category value is assigned only after category list row tap.
- Search/pagination code assumes non-nil category in section 1 and force-unwraps it.

## Severity

- Primary issue (`line 254`): **Critical** user crash risk.
- Related unwraps: **High** (scroll/pagination/admin path crash risk).

## Fix-later recommendation (no code change in this analysis)

1. Replace `category_!` calls with guarded unwrap + safe fallback (`"nil"` or early return).
2. Add guard in section-1 search path to prevent query dispatch when category has not been selected.
3. Add regression checks for switch-to-categories and immediate search.

## Backlog linkage

Tracked in:
- `.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.moviesvc-redesign.tasks` (Phase 10 - Deferred safety hardening backlog)
- `.ai/workflows/features/SwiftUIFeatures/speckit.swiftuifeatures.redesign-ios-dev.execution-plan.md` (Deferred fix-later items)

