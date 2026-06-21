# Swift iOS Data Manager Migration - Complete Index

## Project Overview

**Objective:** Refactor SwiftCinemas iOS client to use centralized shared data managers, removing networking logic from ViewControllers and encapsulating all backend service calls within specialized manager classes.

**Current Status:** Draft specifications prepared for review
**Timeline:** 2 weeks estimated implementation (14.5 hours development)
**Risk Level:** Low (client-side refactor only; no backend changes)
**Rollback:** Simple (git revert VC changes; keep managers for next attempt)

---

## Document Index

### 1. **00-MIGRATION-OVERVIEW.md** ⭐ START HERE
   - **Scope:** High-level overview of current vs. target architecture
   - **Who should read:** Project leads, architects, QA
   - **Key sections:**
     - Current architecture problems
     - Target benefits
     - Migration phases and scope
     - Naming conventions
     - Rollback plan
   - **Read time:** 10 min

### 2. **01-IMPLEMENTATION-GUIDE.md** ⭐ IMPLEMENTERS
   - **Scope:** Step-by-step guide for creating data managers
   - **Who should read:** iOS developers implementing the refactor
   - **Key sections:**
     - Base protocol definition (`SharedDataManager`)
     - Implementation patterns with code examples
     - MoviesData, SeatsData, LocationsData examples
     - ViewController migration examples (Before/After)
     - Testing examples
     - Key principles
   - **Read time:** 20 min + implementation

### 3. **02-READY-TO-IMPLEMENT.md** ⭐ COPY-PASTE CODE
   - **Scope:** Complete ready-to-use code for all 8 data managers
   - **Who should read:** iOS developers starting implementation
   - **Contents:**
     - `SharedDataManager.swift` (base protocol)
     - `SeatsDataManager.swift` (complete)
     - `DatesDataManager.swift` (complete)
     - `VenuesDataManager.swift` (complete)
     - `LocationsDataManager.swift` (complete)
     - `MoviesDataManager.swift` (complete)
     - `AuthDataManager.swift` (complete)
     - `CheckoutDataManager.swift` (complete)
     - Migration checklist
   - **Usage:** Copy code blocks directly into project
   - **Read time:** 5 min (reference as needed)

### 4. **03-ViewController-Migration-Examples.md** ⭐ PRACTICAL EXAMPLES
   - **Scope:** Concrete ViewController migration examples and testing strategies
   - **Who should read:** iOS developers migrating VCs; QA engineers writing tests
   - **Key sections:**
     - MoviesVC before/after comparison
     - VenuesVC before/after comparison
     - CheckoutVC before/after comparison
     - SeatsVC before/after comparison
     - Unit testing data managers (with mocks)
     - Integration testing data managers
     - ViewController UI testing
     - Rollout strategy
     - Verification checklist
   - **Read time:** 15 min + testing

### 5. **04-Quick-Reference.md** ⭐ DEVELOPER CHEATSHEET
   - **Scope:** Quick reference for common tasks and pitfalls
   - **Who should read:** All developers (bookmark this!)
   - **Key sections:**
     - Quick start (5 steps)
     - Dependency map diagram
     - API surface changes (Before/After)
     - File organization
     - Timeline breakdown
     - Common pitfalls & solutions
     - Success metrics
     - Rollback steps
     - FAQ
   - **Read time:** 5 min reference

### 6. **05-Screen-Data-Flow-Migration-Plan.md** ⭐ NAVIGATION STATE
   - **Scope:** Current screen-to-screen data passing audit and migration plan
   - **Who should read:** iOS developers, tech leads, QA
   - **Key sections:**
     - Current segue payload map
     - Global-state risk audit
     - Target manager-owned context properties
     - Phased migration plan and file touch list
     - Validation checklist for regressions
   - **Read time:** 10 min

---

## Implementation Roadmap

### Phase 1: Foundation (2 hours)
- [ ] Read 00-MIGRATION-OVERVIEW.md (understand goals)
- [ ] Read 01-IMPLEMENTATION-GUIDE.md (learn patterns)
- [ ] Create `SharedDataManager.swift` (base protocol)
- [ ] Unit test base protocol

### Phase 2: Core Data Managers (6 hours)
- [ ] Create `MoviesDataManager.swift` (copy from 02-READY-TO-IMPLEMENT.md)
- [ ] Create `SeatsDataManager.swift`
- [ ] Create `DatesDataManager.swift`
- [ ] Create `VenuesDataManager.swift`
- [ ] Create `LocationsDataManager.swift`
- [ ] Unit test each manager with mocks

### Phase 3: Auth & Payment (2 hours)
- [ ] Create `AuthDataManager.swift`
- [ ] Create `CheckoutDataManager.swift`
- [ ] Unit test auth and checkout flows

### Phase 4: ViewController Migration (3 hours)
- [ ] Follow patterns in 03-ViewController-Migration-Examples.md
- [ ] Follow navigation-state migration steps in 05-Screen-Data-Flow-Migration-Plan.md
- [ ] Migrate `MoviesVC` (template for others)
- [ ] Migrate `VenuesVC`, `SeatsVC`, `iOSCalendarVC`
- [ ] Migrate `LoginVC`, `SignupVC`
- [ ] Migrate `CheckoutVC`, `PurchasesVC`
- [ ] Migrate remaining VCs (AdminVC, MenuVC, etc.)
- [ ] Remove global cross-screen state and move context into managers

### Phase 5: Testing & Verification (1.5 hours)
- [ ] Run unit tests (data managers)
- [ ] Run integration tests (real backend)
- [ ] Run Appium E2E suite (no changes expected)
- [ ] Manual smoke tests on iOS device
- [ ] Performance profiling (memory, CPU)

---

## File Changes Summary

### New Files (8 data managers)
```
SwiftCinemas/SwiftLoginScreen/Networking/
  └── SharedDataManager.swift

SwiftCinemas/SwiftLoginScreen/Managers/  [NEW DIRECTORY]
  ├── MoviesDataManager.swift
  ├── SeatsDataManager.swift
  ├── DatesDataManager.swift
  ├── VenuesDataManager.swift
  ├── LocationsDataManager.swift
  ├── AuthDataManager.swift
  ├── CheckoutDataManager.swift
  └── AdminDataManager.swift
```

### Modified Files (20 ViewControllers)
- `MoviesVC.swift` — use `MoviesDataManager.shared`
- `VenuesVC.swift` — use `VenuesDataManager.shared`
- `SeatsVC.swift` — use `SeatsDataManager.shared`
- `iOSCalendarVC.swift` — use `DatesDataManager.shared`
- `LoginVC.swift` — use `AuthDataManager.shared`
- `SignupVC.swift` — use `AuthDataManager.shared`
- `CheckoutVC.swift` — use `CheckoutDataManager.shared`
- `PurchasesVC.swift` — use `CheckoutDataManager.shared`
- `AdminVC.swift` — use `AdminDataManager.shared`
- `AdminUpdateVC.swift` — use `AdminDataManager.shared`
- `MenuVC.swift` — use multiple managers
- `MapViewController.swift` — use `LocationsDataManager.shared`
- `VenuesDetailsVC.swift` — use `VenuesDataManager.shared`
- `VenueForMoviesVC.swift` — use `VenuesDataManager.shared`
- `AttendeesVC.swift` — use relevant managers
- `BasketVC.swift` — use `CheckoutDataManager.shared`
- `MovieDetailVC.swift` — use `MoviesDataManager.shared`
- `HomeVC.swift` — use `MoviesDataManager.shared`
- `TicketsVC.swift` — use `CheckoutDataManager.shared`
- `WebViewController.swift` — minimal or no changes

### Unchanged Files
- `AppDelegate.swift` — no changes
- `Networking/APIClient.swift` — no changes
- `Networking/BackendServices.swift` — no changes
- `Networking/HeaderProvider.swift` — no changes
- `Networking/URLManager.swift` — no changes
- All Storyboards — no changes
- Database/Core Data — no changes

---

## Success Criteria

### Functional Requirements
- ✅ All ViewControllers successfully migrate to use data managers
- ✅ Optional (deferred): Appium E2E can run without modification
- ✅ No regression in movie browsing, seat selection, or checkout
- ✅ Error handling works correctly (network failures, auth errors, etc.)
- ✅ Image caching continues to work with existing Realm storage

### Code Quality
- ✅ Optional (deferred): Unit test coverage targets documented
- ✅ Optional (deferred): Integration test strategy documented
- ✅ No compiler warnings
- ✅ No memory leaks (verified with Instruments)
- ✅ Type-safe API (no raw JSON parsing in VCs)

### Documentation
- ✅ Speckit constitution updated with data manager patterns
- ✅ README updated with architecture overview
- ✅ Code comments explain non-obvious design decisions
- ✅ New developers can understand patterns in <1 hour

---

## Architecture Decision Records (ADRs)

### ADR-001: Singleton Pattern for Data Managers
**Decision:** Use `static let shared` singleton pattern for data managers.
**Rationale:** Simplicity, backward compatibility with existing code patterns.
**Alternative considered:** Dependency injection via protocols (more testable but more complex).
**Trade-off:** Slightly less testable without optional DI init, but simpler API.

### ADR-002: Typed Models Over Raw Data
**Decision:** All fetch methods return strongly-typed models (e.g., `[Movie]`), never raw `Data`.
**Rationale:** Compile-time safety, eliminate JSON parsing errors, self-documenting API.
**Alternative considered:** Continue returning `Data` for flexibility.
**Trade-off:** Slightly more work to create model structs, but massive benefit in safety.

### ADR-003: Error Logging in Managers
**Decision:** Managers log errors with their domain prefix (e.g., `[Movies]`), VCs display to user.
**Rationale:** Centralized error interpretation, easier debugging, consistent logging.
**Alternative considered:** Silent error propagation (VCs handle all logging).
**Trade-off:** Slight redundancy if VC also logs, but provides context for backend issues.

### ADR-004: Async/Await Native (No Callbacks)
**Decision:** All data manager methods are `async throws`, using native Swift concurrency.
**Rationale:** Matches iOS platform direction, simpler code, better tooling support.
**Alternative considered:** Keep callback-based for compatibility.
**Trade-off:** Requires iOS 13+, but already a platform minimum.

---

## Risk Assessment & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Incomplete migration of VCs | Medium | High | Grep for direct endpoint calls in VCs (`app.services.<service>.<endpoint>`); keep protocol-based injection helpers intact |
| Regression in payment flow | Low | High | Run Appium checkout tests on each VC migration |
| Memory leaks from singletons | Low | High | Profile with Instruments; use `[weak self]` in closures |
| Cache invalidation issues | Low | Medium | Leverage existing ResponseCache; no new caching logic |
| Authentication header loss | Low | High | SessionHeaderProvider automatically injected by managers |
| JSON decoding failures | Medium | Medium | All models have optional init; test with malformed JSON |
| Circular dependencies | Low | Medium | Managers don't import VCs; strict one-way dependency |

---

## Validation & Testing Strategy

### Unit Tests
- Data manager initialization
- Successful API calls (mocked)
- API failures (network errors, HTTP errors, auth errors)
- JSON parsing with valid and invalid data
- Thread safety (main thread requirement)

### Integration Tests
- Real backend API calls (staging environment)
- Token refresh and session management
- Payment flow end-to-end
- Image caching with Realm

### UI Tests
- ViewController displays correct data from mock manager
- ViewController shows error alerts on manager failures
- Navigation works correctly with new managers

### E2E Tests (Appium)
- No changes to test suite
- All existing tests should pass without modification
- Covers: login → browse movies → select seats → checkout

---

## Performance Benchmarks

### Expected Metrics
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Time to load movies VC | 1200ms | 1100ms | -8% (less JSON parsing) |
| Memory (MoviesVC) | 24MB | 24MB | ~0% (same data) |
| App startup | 2000ms | 2000ms | ~0% (managers lazy-loaded) |
| Unit test run time | 0s | 300ms | N/A (new tests) |

---

## Speckit Integration

This refactoring will be documented in Speckit for future AI assistance:

```
.ai/workflows/features/Swift_migration/
├── 00-MIGRATION-OVERVIEW.md
├── 01-IMPLEMENTATION-GUIDE.md
├── 02-READY-TO-IMPLEMENT.md
├── 03-ViewController-Migration-Examples.md
├── 04-Quick-Reference.md
├── 05-Screen-Data-Flow-Migration-Plan.md
└── README.md (this file)
```

### Constitution Update
```markdown
## iOS Data Manager Pattern
- **Pattern Name:** Shared Static Data Manager
- **Location:** `SwiftCinemas/SwiftLoginScreen/Managers/*.swift`
- **Base Class:** `SharedDataManager` protocol
- **Naming:** `XyzDataManager` (e.g., `MoviesDataManager`, `SeatsDataManager`)
- **Access:** `XyzDataManager.shared.fetchXyz(...) async throws -> [XyzModel]`
- **Benefits:** Type safety, centralized error handling, easier testing
- **Examples:** See feature specifications in `.ai/workflows/features/Swift_migration/`
```

---

## Post-Implementation Tasks

After all VCs migrated and tested:

1. **Update README**
   - Add section on iOS architecture
   - Link to data manager patterns

2. **Update Contributing.md**
   - Add guideline: "New network calls go in data managers, not VCs"
   - Link to implementation guide

3. **Add to Speckit Constitution**
   - Document data manager pattern as standard practice
   - Include ADRs and design rationale

4. **Deprecate old patterns**
   - Mark static `addData()` methods as `@deprecated`
   - Add warning comments directing to managers

5. **Future improvements**
   - Consider SwiftUI support (struct-based data managers)
   - Add caching strategies (LRU, TTL)
   - Add analytics tracking

---

## Questions for Reviewers

Before implementation, please address:

1. **Naming:** Are manager names clear? (`MoviesDataManager` vs. `MovieManager` vs. `MovieFetcher`?)
2. **Location:** Should managers be in `/Managers/` subdirectory or alongside VCs?
3. **Initialization:** Singleton vs. DI—should we support both for testing?
4. **Admin endpoints:** Should `AdminDataManager` handle all admin operations?
5. **Rollout:** Should we migrate all VCs at once or one-at-a-time per sprint?

---

## Approval Checklist

- [ ] Architecture reviewed and approved
- [ ] Timeline and resource allocation confirmed
- [ ] Risk mitigation strategies accepted
- [ ] Testing strategy signed off
- [ ] Rollback plan documented and approved
- [ ] Team training scheduled (45 min overview)
- [ ] Speckit integration planning underway
- [ ] QA team briefed on testing strategy

---

## References

- **Project Constitution:** `.ai/constitution/constitution.md`
- **Architecture Overview:** `.ai/agents/AGENTS.md`
- **iOS Networking:** `SwiftCinemas/SwiftLoginScreen/Networking/`
- **System Documentation:** `k8infra/system-documentation.html`
- **Appium Tests:** `appium/src/test/java/qa.ios.test/`

---

## Contact

**Lead Architect:** [Your name here]
**Implementation Lead:** [Your name here]
**QA Lead:** [Your name here]

For questions, refer to the specific document sections above or reach out directly.

---

**Status:** ✅ Ready for review and implementation
**Last Updated:** May 5, 2026
**Version:** 1.0-draft

