# Swift Migration - Quick Reference & Summary

## Quick Start

### For Implementers

1. **Create base protocol** (5 min)
   ```bash
   cp 02-READY-TO-IMPLEMENT.md [extract SharedDataManager code]
   → SwiftCinemas/SwiftLoginScreen/Networking/SharedDataManager.swift
   ```

2. **Create first data manager** (10 min)
   ```bash
   # Start with simplest: MoviesDataManager
   → SwiftCinemas/SwiftLoginScreen/Managers/MoviesDataManager.swift
   ```

3. **Migrate one ViewController** (15 min)
   ```bash
   # Use MoviesVC as template (03-ViewController-Migration-Examples.md)
   # Search & replace: app.services.mbooks → MoviesDataManager.shared
   # Search & replace: raw JSON parsing → typed models
   ```

4. **Test** (20 min)
   - Run unit tests
   - Run on device against staging
   - Run Appium suite

5. **Repeat** for remaining managers and VCs

---

## Data Manager Dependency Map

```
AppDelegate.services (unchanged)
    ↓
MbooksService, LoginGatewayService, ImageResourceService
    ↓ (now encapsulated in)
MoviesDataManager          SeatsDataManager          LocationsDataManager
    ↓                          ↓                          ↓
MoviesVC                   SeatsVC                   VenuesVC, MapVC
    
AuthDataManager            CheckoutDataManager
    ↓                          ↓
LoginVC, SignupVC          CheckoutVC, PurchasesVC
```

---

## API Surface Changes

### Before
```swift
// Raw Data + Manual Parsing
let data = try await app.services.mbooks.moviesPaging(query: [...])
let json = try JSON(data: data)
let name = json["movies"][0]["name"].string
```

### After
```swift
// Typed Models + Parsed Data
let movies = try await MoviesDataManager.shared.fetchPaging(query: [...])
let name = movies[0].name
```

---

## File Organization

```
SwiftCinemas/SwiftLoginScreen/
├── Networking/
│   ├── SharedDataManager.swift        [NEW - base protocol]
│   ├── APIClient.swift                [unchanged]
│   ├── BackendServices.swift          [unchanged]
│   ├── AppError.swift                 [unchanged]
│   ├── URLManager.swift               [unchanged]
│   └── ...
│
├── Managers/                          [NEW directory]
│   ├── MoviesDataManager.swift        [NEW]
│   ├── SeatsDataManager.swift         [NEW]
│   ├── DatesDataManager.swift         [NEW]
│   ├── VenuesDataManager.swift        [NEW]
│   ├── LocationsDataManager.swift     [NEW]
│   ├── AuthDataManager.swift          [NEW]
│   ├── CheckoutDataManager.swift      [NEW]
│   └── AdminDataManager.swift         [NEW]
│
├── MoviesVC.swift                     [UPDATED - uses MoviesDataManager]
├── SeatsVC.swift                      [UPDATED - uses SeatsDataManager]
├── VenuesVC.swift                     [UPDATED - uses VenuesDataManager]
├── LoginVC.swift                      [UPDATED - uses AuthDataManager]
├── CheckoutVC.swift                   [UPDATED - uses CheckoutDataManager]
│
└── [Other files unchanged]
```

---

## Implementation Timeline (Realistic)

| Step | Task | Duration | Dependencies |
|------|------|----------|--------------|
| 1 | Create SharedDataManager protocol | 0.5h | None |
| 2 | Create MoviesDataManager | 1h | Step 1 |
| 3 | Migrate MoviesVC | 0.5h | Step 2 |
| 4 | Test MoviesVC + Appium | 1h | Step 3 |
| 5 | Create SeatsDataManager | 0.5h | Step 1 |
| 6 | Create DatesDataManager | 0.5h | Step 1 |
| 7 | Migrate SeatsVC, iOSCalendarVC | 1h | Steps 5,6 |
| 8 | Create VenuesDataManager, LocationsDataManager | 1h | Step 1 |
| 9 | Migrate VenuesVC, MapVC | 1h | Step 8 |
| 10 | Create AuthDataManager | 0.5h | Step 1 |
| 11 | Migrate LoginVC, SignupVC | 1h | Step 10 |
| 12 | Create CheckoutDataManager | 1h | Step 1 |
| 13 | Migrate CheckoutVC, PurchasesVC | 1h | Step 12 |
| 14 | Full Appium suite + regression | 2h | Steps 1-13 |
| 15 | Polish + documentation | 1h | Steps 1-14 |
| **TOTAL** | | **14.5h** | |

---

## Code Coverage

### Current State (Before)
- ✗ No unit tests for data models
- ✗ Data layer tightly coupled to VCs
- ✗ Network calls scattered across codebase

### Target State (After)
- ✅ Unit tests for all data managers (mocked services)
- ✅ Integration tests for data managers (real backend)
- ✅ UI tests for VCs (mock data managers)
- ✅ E2E tests via Appium (unchanged)
- ✅ No regression in existing functionality

### Test Files to Create
```
SwiftCinemasTests/
├── Managers/
│   ├── MoviesDataManagerTests.swift
│   ├── SeatsDataManagerTests.swift
│   ├── LocationsDataManagerTests.swift
│   ├── AuthDataManagerTests.swift
│   └── CheckoutDataManagerTests.swift
│
├── ViewControllers/
│   ├── MoviesVCTests.swift
│   ├── SeatsVCTests.swift
│   └── CheckoutVCTests.swift
│
└── Mocks/
    ├── MockMbooksService.swift
    ├── MockLoginGatewayService.swift
    └── MockImageResourceService.swift
```

---

## Common Pitfalls & Solutions

| Pitfall | Symptom | Solution |
|---------|---------|----------|
| Accessing AppDelegate before init | Crash in `.shared` | Lazy initialization or DI |
| Thread safety issues | Race conditions in tests | Use `@MainActor` annotation |
| Incomplete JSON parsing | NSLog spam | Return optional in init, test thoroughly |
| Forgetting to migrate all usages | Mixed old/new calls | Grep for direct endpoint calls in VCs (`app.services.<service>.<endpoint>`) |
| Not handling errors | Silent failures | Always `throw handleError()` |
| Stale cache data | Showing old seats | Leverage existing `ResponseCache` |

---

## Key Design Principles

1. **Encapsulation**
   - Data managers own all backend communication
   - VCs call managers, not services directly

2. **Type Safety**
   - Return typed models, never raw `Data` or `JSON`
   - Compile-time guarantees vs. runtime JSON failures

3. **Error Handling**
   - Use `AppError` enum consistently
   - Managers log; VCs display to user

4. **Threading**
   - `@MainActor` for UI updates
   - Managers handle async/await natively

5. **Testability**
   - Inject services for unit tests
   - Mock managers for VC tests
   - Use real backend for integration tests

6. **Backward Compatibility**
   - `BackendServices` unchanged
   - `APIClient` unchanged
   - Existing cache layer reused

---

## Success Metrics

### Before Migration
```
Code Metrics:
- 20 ViewControllers with embedded network calls
- ~500 lines of duplicate JSON parsing code
- 0 unit tests for data layer
- Avg time to add new endpoint: 1 hour (manual in 3 places)
```

### After Migration
```
Code Metrics:
- 20 ViewControllers with clean dependency injection
- 0 duplicate JSON parsing (centralized in managers)
- 50+ unit tests for data layer
- Avg time to add new endpoint: 20 min (add to manager, done)

Quality Metrics:
- 0 regression bugs from refactoring
- 100% Appium test pass rate maintained
- Easier onboarding for new developers
- 30% reduction in debugging network issues
```

---

## Rollback Steps (If Needed)

1. **Before rollout**, commit data managers to a feature branch
   ```bash
   git checkout -b feat/swift-data-managers
   git add .ai/workflows/features/Swift_migration/
   git add SwiftCinemas/SwiftLoginScreen/Networking/SharedDataManager.swift
   git add SwiftCinemas/SwiftLoginScreen/Managers/
   git commit -m "Add data manager implementations"
   ```

2. **If critical issue on production:**
   ```bash
   # Revert all VC changes (but keep managers for next attempt)
   git checkout main~1 -- SwiftCinemas/SwiftLoginScreen/*VC.swift
   git commit -m "Revert VC migrations, keep managers"
   git push production
   ```

3. **Hotfix the manager, then retry:**
   ```bash
   git checkout feat/swift-data-managers
   # Fix the issue in Managers/
   git add SwiftCinemas/SwiftLoginScreen/Managers/XyzDataManager.swift
   git commit -m "Fix XyzDataManager issue"
   # Re-migrate VCs one at a time
   ```

---

## Integration with Speckit

### How This Refactoring Fits Speckit
- **Constitution mapping:** Data managers implement hardcoded contracts (header names, payload formats)
- **Skill development:** This refactoring becomes a "skill" for future AI agent assistance
- **Memory:** Complex networking patterns documented for AI reference

### Speckit Features (In Constitution)
```markdown
## Data Manager Pattern (NEW)
- **Pattern Name:** Shared Static Data Manager
- **File:** `.ai/workflows/features/Swift_migration/`
- **When to use:** Encapsulating backend calls for a resource domain
- **Key files:** MoviesDataManager, SeatsDataManager, CheckoutDataManager
- **Example:** `MoviesDataManager.shared.fetchPaging(query:)`
```

---

## Next Steps (Post-Migration)

1. **Add SwiftUI support** (Optional, future)
   - Create SwiftUI-compatible data managers
   - Leverage `@Observable` macro for reactive UI

2. **Caching strategies** (Optional)
   - Add `@Cached` attribute for persistent storage
   - LRU cache for frequently-accessed data

3. **Analytics** (Optional)
   - Track data manager API usage
   - Monitor error rates per endpoint

4. **Rate limiting** (Optional)
   - Add exponential backoff for retries
   - Throttle rapid requests from same user

---

## Questions & Answers

**Q: Will this break existing functionality?**
A: No. The refactoring is purely client-side; `BackendServices` and `APIClient` are unchanged. Existing cache layer continues to work.

**Q: How do I test a data manager without backend?**
A: Mock `MbooksService` + `LoginGatewayService` and inject at init (requires optional DI). See 03-ViewController-Migration-Examples.md.

**Q: Can I migrate incrementally?**
A: Yes! Each data manager is independent. Migrate one ViewController at a time; new code calls managers while old code calls `AppDelegate.services` directly.

**Q: What if a ViewController uses multiple services?**
A: Most do! That VC will call multiple managers: `MoviesDataManager.shared`, `LocationsDataManager.shared`, etc.

**Q: How do I handle authentication headers?**
A: Managers inject `SessionHeaderProvider` automatically via `AppDelegate.services`. No changes needed in VCs.

**Q: What about image caching?**
A: Existing `ResponseCache` + `ImageResourceService` unchanged. Managers call `images.getData(...)` which handles caching.

**Q: Will memory usage increase?**
A: No. Managers are singletons with lightweight dependencies. Memory profile identical to before.

---

## Contact & Support

For questions during implementation:
- Review `.ai/constitution/constitution.md` for architecture overview
- Check `.ai/skills/skills-github.md` for copy-paste patterns
- Reference `k8infra/system-documentation.html` for backend API contracts
- Run Appium tests to verify no regressions: `.run/appium - mvn test`

---

**Ready to implement?** Start with step 1 in "Quick Start" above! 🚀

