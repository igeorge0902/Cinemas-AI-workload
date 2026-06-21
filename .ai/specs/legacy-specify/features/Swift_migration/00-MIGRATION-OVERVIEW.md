# Swift iOS Shared Data Managers Migration

## Objective
Refactor the iOS codebase to centralize backend service calls into shared static data managers, removing networking logic from ViewControllers and encapsulating backend calls within specialized data model classes.

## Current Architecture (Before)
```
ViewControllers
    ↓ (direct API calls)
AppDelegate.services.mbooks / .loginGateway / .images
    ↓ (via BackendServices.swift)
APIClient → URLSession → Backend
```

**Problems:**
- Network calls scattered across ViewControllers
- Data models are simple POJOs without service integration
- Tight coupling between UI and networking
- Code duplication across VCs when fetching similar data
- Difficult to test and maintain

## Target Architecture (After)
```
ViewControllers
    ↓ (clean dependency)
SharedDataManagers (e.g., MoviesData.shared, SeatsData.shared)
    ↓ (encapsulated calls)
BackendServices (still via AppDelegate.services)
    ↓
APIClient → URLSession → Backend
```

**Benefits:**
- **Single Responsibility:** Each data manager handles one resource domain
- **Reusability:** VCs call `MoviesData.shared.fetchPaging(query:)` consistently
- **Testability:** Mock data managers in tests without network
- **Maintainability:** Backend integration logic in one place per resource
- **Clean UI:** ViewControllers focus on UI logic, not networking

## Migration Scope

### Phase 1: Create Shared Data Manager Base Class
- Define `SharedDataManager<T>` protocol/base class
- Provide common error handling, threading, caching patterns
- Establish naming conventions (e.g., `class MoviesData: SharedDataManager`)

### Phase 2: Refactor Existing Data Models
Target models to refactor (in priority order):
1. `MoviesData` — fetch paging, search, trending
2. `SeatsData` — fetch seats by screening
3. `PlacesData` → `LocationsData` — fetch locations, venues by location
4. `ScreenData` — fetch dates and screens
5. `UserData` — login/auth endpoints
6. `PurchaseData`, `TicketsData`, `BasketData` — checkout and purchases
7. `Admin_ScreenData` — admin operations

### Phase 3: Update ViewControllers
- Replace direct endpoint calls (for example `app.services.mbooks.*`) with `XyzData.shared` calls
- Use `@MainActor` for UI updates (already in place)
- Keep existing protocol-based injection (`HasAPIClient`, `injectAPIClientIfNeeded`, `HasAppServices`) unchanged

### Phase 4: Add Specialized Managers (Optional)
- `PaymentManager` — wraps checkout flow
- `SessionManager` — login state and token refresh
- `ImageCacheManager` — image fetching + caching

---

## Implementation Pattern: MoviesData Example

### Before (Current)
```swift
// MoviesVC.swift
func loadMovies() {
    Task { @MainActor in
        guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
        do {
            let data = try await app.services.mbooks.moviesPaging(query: ["setFirstResult": "0"])
            let json = try JSON(data: data)
            // process JSON...
            tableView.reloadData()
        } catch {
            NSLog("Error: %@", error.localizedDescription)
        }
    }
}
```

### After (Refactored)
```swift
// MoviesData.swift (refactored)
final class MoviesData: SharedDataManager<Movie> {
    static let shared = MoviesData()
    
    private override init() { /* ... */ }
    
    // Backend service dependency
    private let mbooks: MbooksService
    
    required init(mbooks: MbooksService) {
        self.mbooks = mbooks
    }
    
    /// Fetch paginated movies; returns parsed [Movie]
    func fetchPaging(query: [String: String]) async throws -> [Movie] {
        let data = try await mbooks.moviesPaging(query: query)
        let json = try JSON(data: data)
        
        guard let list = json["movies"].array else {
            throw AppError.decodingFailed
        }
        
        return list.compactMap { Movie(json: $0) }
    }
}

// MoviesVC.swift (refactored)
func loadMovies() {
    Task { @MainActor in
        do {
            let movies = try await MoviesData.shared.fetchPaging(
                query: ["setFirstResult": "0"]
            )
            self.movieList = movies
            tableView.reloadData()
        } catch {
            NSLog("Error: %@", error.localizedDescription)
        }
    }
}
```

---

## Naming Conventions

| Category | Pattern | Example |
|----------|---------|---------|
| Data Manager | `ClassName` | `MoviesData`, `SeatsData`, `LocationsData` |
| Shared Instance | `.shared` | `MoviesData.shared` |
| Fetch Methods | `fetch*` | `fetchPaging()`, `fetchSeats()`, `fetchLocations()` |
| Error Handling | Use `AppError` enum | `throw AppError.networkFailure(...)` |
| Threading | `@MainActor` | UI updates on main thread |
| Backend Service | Injected or via `AppDelegate.services` | `self.mbooks`, `self.loginGateway` |

---

## Key Design Decisions

1. **Shared Pattern vs Dependency Injection**
   - Use `shared` singleton for simplicity and backwards compatibility
   - Optional: Add DI protocol for testing (e.g., `HasMoviesData`)

2. **Backend Service Access**
   - Inject `MbooksService`, `LoginGatewayService`, etc. into init
   - Or access via `AppDelegate.services` (simpler, but less testable)

3. **Return Types**
   - Data managers return **parsed models**, not raw `Data`
   - Example: `async throws -> [Movie]` instead of `async throws -> Data`

4. **Caching**
   - Leverage existing `ResponseCache` via `APIClient`
   - Data managers don't duplicate cache logic; rely on `BackendServices`

5. **Error Handling**
   - Use `AppError` enum consistently
   - Add specialized error types if needed (e.g., `InvalidSeatsError`)

---

## Refactoring Checklist

### For Each Data Model (`XyzData.swift`)
- [ ] Convert to singleton (if not already)
- [ ] Add backend service dependency (inject or access from `AppDelegate`)
- [ ] Create `fetch*()` methods encapsulating API calls + JSON parsing
- [ ] Replace static `class func addData()` with instance methods
- [ ] Return strongly typed models, not raw `Data`
- [ ] Add error logging with meaningful messages
- [ ] Mark async methods with appropriate actor annotations

### For Each ViewController Using the Data Model
- [ ] Replace direct endpoint calls (`app.services.<service>.<endpoint>`) with `XyzData.shared`
- [ ] Replace raw `JSON` parsing with typed model objects
- [ ] Remove `@MainActor` wrapper from network calls (let manager handle)
- [ ] Keep `@MainActor` for UI updates only
- [ ] Test error handling path

---

## Testing Strategy

### Unit Tests
```swift
class MoviesDataTests: XCTestCase {
    var mockMbooks: MockMbooksService!
    var moviesData: MoviesData!
    
    override func setUp() {
        mockMbooks = MockMbooksService()
        moviesData = MoviesData(mbooks: mockMbooks)
    }
    
    func testFetchPagingSuccess() async throws {
        let movies = try await moviesData.fetchPaging(query: ["setFirstResult": "0"])
        XCTAssertEqual(movies.count, 5)
    }
    
    func testFetchPagingFailure() async {
        mockMbooks.shouldFail = true
        do {
            _ = try await moviesData.fetchPaging(query: [:])
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is AppError)
        }
    }
}
```

### Integration Tests
- Keep existing Appium E2E tests (no changes)
- Add API-level tests for data manager methods
- Test with real backend in staging

---

## Migration Timeline

| Phase | Tasks | Effort | Timeline |
|-------|-------|--------|----------|
| 1 | Create base class + protocols | 4h | Week 1 Mon |
| 2a | Refactor MoviesData, VenuesData | 8h | Week 1 Tue–Wed |
| 2b | Refactor SeatsData, DatesData | 6h | Week 1 Thu |
| 2c | Refactor Auth, Checkout, Purchases | 10h | Week 2 Mon–Tue |
| 3 | Update all VCs (20+ files) | 12h | Week 2 Wed–Fri |
| 4 | Testing + polish | 6h | Week 3 Mon |
| **Total** | | **46h** | **~2 weeks** |

---

## Rollback Plan

If issues arise:
1. Revert commits to specific data managers (git reset)
2. Keep networking layer (`BackendServices`, `APIClient`) intact
3. ViewControllers can temporarily call `AppDelegate.services` directly
4. No schema/backend changes needed (purely client-side refactor)

---

## References

- Current networking: `SwiftCinemas/SwiftLoginScreen/Networking/BackendServices.swift`
- Existing data models: `SwiftCinemas/SwiftLoginScreen/*Data.swift`
- ViewControllers: `SwiftCinemas/SwiftLoginScreen/*VC.swift`
- Error handling: `SwiftCinemas/SwiftLoginScreen/Networking/AppError.swift`

