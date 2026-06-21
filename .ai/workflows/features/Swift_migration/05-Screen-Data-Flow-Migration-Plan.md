# Screen-to-Screen Data Flow Migration Plan

## Purpose

This document maps how data currently moves between screens and defines a migration plan to move cross-screen state into shared data manager properties.

---

## Current Navigation Data Flow (Observed)

### A) Movie Discovery Flow
- `MoviesVC` -> `VenuesVC` via segue `goto_venues`
  - Passes: `movieId`, `movieName`, `selectDetails`, `selectLarge_picture`, `imdb`
- `MoviesVC` -> `MovieDetailVC` via segue `goto_movie_detail`
  - Passes: same movie payload
- `MovieDetailVC` -> `VenuesVC` via segue `goto_venues2`
  - Passes: same movie payload again

### B) Venue and Map Flow
- `VenuesVC` -> `VenuesDetailsVC` via segue `goto_venues_details`
  - Passes venue payload + movie payload + `locationId`
- `VenuesDetailsVC` -> `MapViewController` via segue `goto_map2`
  - Passes: `selectVenueId`, `map2`
- `MapViewController` -> `VenueForMoviesVC` via segue `goto_venues_for_movies`
  - Passes: `locationId_`

### C) Booking Flow
- `VenuesDetailsVC` opens `PopOverDates` and writes global `screeningDateId`
- `VenuesDetailsVC` opens `PopOver` and reads global `screeningDateId`
- `PopOver` writes globals `seatsToBeReserved`, `Seats`, `BasketData_`
- `PopOver` opens `BasketVC` which reads `BasketData_` and `Seats`

### D) Purchases Flow
- `PurchasesVC` -> `TicketsVC` via segue `goto_tickets`
  - Passes: `purchaseId`

---

## Main Risks in Current Pattern

1. Global mutable state leaks between sessions (`BasketData_`, `SeatsData_`, `PlacesData_`, `screeningDateId`).
2. The same movie payload is passed in multiple segues, increasing drift risk.
3. `prepare(for:)` blocks duplicate mapping logic and require manual sync when models change.
4. NotificationCenter string events are untyped and easy to break silently.
5. Flows are hard to test in isolation because state is not owned by one domain.

---

## Target Pattern: Manager-Owned Navigation Context

### Shared context owners
- `MoviesDataManager.shared`
  - `selectedMovie: MovieDataModel?`
  - `browseList: [MovieDataModel]`
  - `searchList: [MovieDataModel]`
- `VenuesDataManager.shared`
  - `selectedVenue: VenueDataModel?`
  - `venuesForSelectedMovie: [VenueDataModel]`
- `LocationsDataManager.shared`
  - `selectedLocationId: Int?`
  - `isMapFromVenueDetails: Bool`
- `DatesDataManager.shared`
  - `selectedScreeningDateId: String?`
  - `selectedScreeningDateText: String?`
- `SeatsDataManager.shared`
  - `seatsForSelectedScreening: [SeatDataModel]`
  - `selectedSeatNumbers: [String]`
  - `selectedSeatIds: [Int]`
- `BasketDataManager.shared`
  - `basketItemsBySeatId: [Int: BasketItemModel]`
  - `seatsToReservePayloadByScreening: [String: String]`
- `PurchasesDataManager.shared`
  - `selectedPurchaseId: String?`

### VC responsibility after migration
- Write selected IDs/models into manager context before navigation.
- Read manager context in destination VC `viewDidLoad`/`viewWillAppear`.
- Keep segue only for navigation intent (no heavy payload copying).

---

## Migration Plan (Phased)

### Phase 1: Context Contracts
1. Define context properties on each manager.
2. Add `resetNavigationContext()` per manager for safe cleanup.
3. Add lightweight typed context structs where useful.

### Phase 2: Movie + Venue + Map
1. `MoviesVC`: set `MoviesDataManager.shared.selectedMovie` before opening details/venues.
2. `MovieDetailVC`: read selected movie from manager; stop duplicate movie payload assignments.
3. `VenuesVC`: read selected movie from manager and set `VenuesDataManager.shared.selectedVenue`.
4. `VenuesDetailsVC` and `MapViewController`: consume venue/location manager context.

### Phase 3: Dates + Seats + Basket
1. Move `screeningDateId` and date text from globals into `DatesDataManager`.
2. Move `SeatsData_`, `seatsToBeReserved`, `Seats` into `SeatsDataManager` + `BasketDataManager`.
3. `PopOver` and `BasketVC` read/write only manager properties.

### Phase 4: Purchases + Tickets
1. `PurchasesVC` sets `PurchasesDataManager.shared.selectedPurchaseId` on row select.
2. `TicketsVC` reads selected purchase id from manager context.

### Phase 5: Cleanup + Verification
1. Remove global state declarations and NotificationCenter string-based state passing.
2. Keep only navigation segues and IDs.
3. Execute regression checklist for booking, map, and purchases paths.

---

## File Touch Plan

- `SwiftCinemas/SwiftLoginScreen/MoviesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/MovieDetailVC.swift`
- `SwiftCinemas/SwiftLoginScreen/VenuesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/VenuesDetailsVC.swift`
- `SwiftCinemas/SwiftLoginScreen/MapViewController.swift`
- `SwiftCinemas/SwiftLoginScreen/PopOverDates.swift`
- `SwiftCinemas/SwiftLoginScreen/PopOver.swift`
- `SwiftCinemas/SwiftLoginScreen/BasketVC.swift`
- `SwiftCinemas/SwiftLoginScreen/PurchasesVC.swift`
- `SwiftCinemas/SwiftLoginScreen/TicketsVC.swift`
- `SwiftCinemas/SwiftLoginScreen/Managers/*DataManager.swift`

---

## Validation Checklist

- [ ] No global cross-screen state variables remain (`BasketData_`, `SeatsData_`, `PlacesData_`, `screeningDateId`, `Seats`).
- [ ] `prepare(for:)` no longer maps full domain payloads repeatedly.
- [ ] Booking flow still preserves selected date, seat list, and checkout payload.
- [ ] Map flow still supports venue details -> map and map -> venues path.
- [ ] Purchases -> tickets uses the correct selected purchase id.
- [ ] Appium suite passes for Movies -> Venues -> Dates -> Seats -> Basket -> Checkout.
- [ ] Appium suite passes for Purchases -> Tickets.

