# SwiftUI Migration — Specification & Skills

This directory contains comprehensive specifications and skill guides for migrating the iOS Cinemas app from UIKit globals to SwiftUI-compatible reactive patterns.

## Files

### Specifications (`.specify` files)

1. **`speckit.migration.specify`**
   - Main feature spec: Venues screen migration to SwiftUI
   - Covers three operational modes (standard, admin, map)
   - Global state dependencies and migration strategy

2. **`speckit.migration.alertcontrollers.specify`**
   - Feature spec: Standardize alerts and WebSocket integration
   - Consolidates alert helpers from scattered VCs
   - Adds typed alert actions and WebSocket message publishing

3. **`speckit.migration.globalvariables.specify`** ⭐ **NEW**
   - Feature spec: Replace all iOS-wide global variables with DataManagers
   - Complete inventory of 9 global lists/dictionaries
   - Phased migration plan (Basket → Venues → Movies → Admin)
   - **NEW SECTION:** API integration pattern showing how responses flow into DataManagers
   - 4 DataManager classes to create; 13+ files to modify

### Skills (Guide Documents)

4. **`skills.datamanager-api-integration.swift`** ⭐ **NEW**
   - Intermediate-level skill: How to wire API responses into DataManagers
   - 9 detailed patterns with before/after code examples
   - Covers static fetch functions, error handling, main-thread safety
   - Checklist for refactoring a single global → DataManager
   - Code is formatted as Swift comments for IDE readability

5. **`api-to-datamanager-mapping.md`** ⭐ **NEW**
   - Reference guide: All API endpoints → DataManager targets
   - Detailed flow diagrams for each service (mbooks, images, loginGateway)
   - Response format examples in JSON
   - Summary table mapping current write targets to new DataManager properties
   - Best practices for API integration

### Task & Plan Files

6. **`speckit.migration.plan`**
   - Roadmap and sequencing for all migration phases

7. **`speckit.migration.tasks`**
   - Granular task breakdown for execution

---

## How to Use These Documents

### For Developers Implementing the Feature

1. **Start with:** `speckit.migration.globalvariables.specify`
   - Read overview, current globals inventory, and goals
   - Understand the 4 DataManagers to create

2. **Understand the pattern:** `skills.datamanager-api-integration.swift`
   - Study the before/after examples
   - Learn the checklist for refactoring
   - Reference main-thread and error handling patterns

3. **Look up API flows:** `api-to-datamanager-mapping.md`
   - Find which API endpoints populate which DataManager properties
   - Copy the parsing/mapping code snippets
   - Verify you're writing to the right property

4. **Execute tasks:** Use `speckit.migration.tasks` and `speckit.migration.plan`
   - Follow the phased migration order (Basket → Venues → Movies → Admin)
   - Test each phase before moving to the next

### For Code Review

- **REQ-DM-*** and **REQ-API-*** sections in the spec define the acceptance criteria
- **Success Criteria** section lists all completion checklist items
- Reference the skill guide to verify refactoring patterns are correct

### For Architecture Discussion

- See **Architecture Constraints** and **Integration Points** sections
- Understand why each design decision was made
- Use the phased migration order to discuss risk vs. benefit

---

## Key Concepts

### Global Variables → DataManagers

**Before:** Module-level globals like `var PlacesData_: [PlacesData] = []`
- Shared across VCs via direct reference
- Mutated in place; cleanup in `deinit`
- No reactive observers; VCs manually call `tableView.reloadData()`

**After:** Observable DataManager classes like `VenuesDataManager`
- Held by AppServices; accessed via `HasAppServices` protocol
- @Published properties trigger Combine publishers
- VCs subscribe with `sink`; SwiftUI views use `@ObservedObject`
- Centralized reset logic via `manager.reset()`

### API Integration Pattern

```
VenuesVC.addLocation()
    ↓
try await appServices.mbooks.locations()
    ↓
JSON parse + model instantiation
    ↓
appServices.venues.venues = [...]
    ↓
@Published triggers all observers
```

### Four DataManagers

| Manager | Properties | Replaces Global(s) |
|---------|------------|-------------------|
| **MoviesDataManager** | `movies`, `adminScreenings` | `TableData_`, `ScreenData_2` |
| **VenuesDataManager** | `venues`, `filteredVenues` | `PlacesData_`, `PlacesData2_` |
| **AdminDataManager** | `screenings` | `ScreenData_` |
| **BasketDataManager** | `items`, `seats`, `tickets`, `ticketMap` | `BasketData_`, `SeatsData_`, `TicketsData_`, `tickets` dict |

---

## Phased Migration Order

1. **Phase 1:** BasketDataManager (highest risk, most shared)
2. **Phase 2:** VenuesDataManager
3. **Phase 3:** MoviesDataManager
4. **Phase 4:** AdminDataManager
5. **Phase 5:** Cleanup (delete old globals)

Each phase includes:
- Create DataManager class
- Register in AppServices
- Migrate all read/write sites
- Update static fetch functions
- Update deinit blocks
- Integration testing

---

## Files to Create (Phase 1–4)

### New DataManagers
- `SwiftLoginScreen/DataManagers/MoviesDataManager.swift`
- `SwiftLoginScreen/DataManagers/VenuesDataManager.swift`
- `SwiftLoginScreen/DataManagers/AdminDataManager.swift`
- `SwiftLoginScreen/DataManagers/BasketDataManager.swift`

### Modified Files (13+)
- AppServices.swift (register managers)
- MoviesVC.swift
- AdminVC.swift
- AdminUpdateVC.swift
- MapViewController.swift
- VenuesVC.swift
- VenuesMigration.swift
- BasketVC.swift
- PopOver.swift
- HomeVC.swift
- SeatsData.swift
- TicketsData.swift (if static fetch exists)
- Plus any other VCs that reference globals

---

## Success Metrics

✅ **Completion checklist from spec:**

- [ ] No bare global array/dictionary variables remain (except mode-flag booleans)
- [ ] All four DataManagers exist under `SwiftLoginScreen/DataManagers/`
- [ ] AppServices holds and vends all four DataManagers
- [ ] All VC usages compile and reference manager properties via appServices
- [ ] SeatsData.addData() and MoviesData.addData() still work (data appears in UI)
- [ ] All API calls routed through appServices; responses written into DataManagers
- [ ] SwiftUI VenuesMigration reads from VenuesDataManager (no bare globals)
- [ ] deinit blocks call manager.reset() instead of global.removeAll()
- [ ] Error handling preserved; all errors logged with NSLog
- [ ] All @Published writes occur on @MainActor
- [ ] No regression in any flow (movies, basket, seats, payment, admin, images)

---

## References

- **Combine documentation:** https://developer.apple.com/documentation/combine
- **ObservableObject:** https://developer.apple.com/documentation/combine/observableobject
- **@Published:** https://developer.apple.com/documentation/combine/published
- **AppServices pattern:** Existing in AppDelegate.swift (lines 27–42)
- **HasAppServices protocol:** Used by all VCs in codebase

---

## Questions?

Refer to the inline comments in `skills.datamanager-api-integration.swift` for common patterns, or check the specific API endpoint section in `api-to-datamanager-mapping.md`.

